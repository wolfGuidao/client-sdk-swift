/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if os(iOS)

import Foundation

#if canImport(ReplayKit)
import ReplayKit
#endif

private enum Constants {
    static let bufferMaxLength = 10240
}

class SampleUploader {
    private static var imageContext = CIContext(options: nil)
    private static var colorSpace = CGColorSpaceCreateDeviceRGB()

    @Atomic private var isReady = false
    private var connection: BroadcastUploadSocketConnection

    private var dataToSend: Data?
    private var byteIndex = 0

    private let serialQueue: DispatchQueue

    // Configure desired compression quality (0.0 = max compression, 1.0 = least compression)
    public let compressionQuality: CGFloat = 1.0

    init(connection: BroadcastUploadSocketConnection) {
        self.connection = connection
        serialQueue = DispatchQueue(label: "io.livekit.broadcast.sampleUploader")

        setupConnection()
    }

    @discardableResult func send(sample buffer: CMSampleBuffer) -> Bool {
        guard isReady else {
            return false
        }

        isReady = false

        dataToSend = prepare(sample: buffer)
        byteIndex = 0

        serialQueue.async { [weak self] in
            self?.sendDataChunk()
        }

        return true
    }
}

private extension SampleUploader {
    func setupConnection() {
        connection.didOpen = { [weak self] in
            self?.isReady = true
        }
        connection.streamHasSpaceAvailable = { [weak self] in
            self?.serialQueue.async {
                if let success = self?.sendDataChunk() {
                    self?.isReady = !success
                }
            }
        }
    }

    @discardableResult func sendDataChunk() -> Bool {
        guard let dataToSend else {
            return false
        }

        var bytesLeft = dataToSend.count - byteIndex
        var length = bytesLeft > Constants.bufferMaxLength ? Constants.bufferMaxLength : bytesLeft

        length = dataToSend[byteIndex ..< (byteIndex + length)].withUnsafeBytes {
            guard let ptr = $0.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }

            return connection.writeToStream(buffer: ptr, maxLength: length)
        }

        if length > 0 {
            byteIndex += length
            bytesLeft -= length

            if bytesLeft == 0 {
                self.dataToSend = nil
                byteIndex = 0
            }
        } else {
            logger.log(level: .debug, "writeBufferToStream failure")
        }

        return true
    }

    func prepare(sample buffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            logger.log(level: .debug, "image buffer not available")
            return nil
        }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        let orientation = CMGetAttachment(buffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil)?.uintValue ?? 0

        let bufferData = jpegData(from: imageBuffer)

        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        guard let messageData = bufferData else {
            logger.log(level: .debug, "corrupted image buffer")
            return nil
        }

        let httpResponse = CFHTTPMessageCreateResponse(nil, 200, nil, kCFHTTPVersion1_1).takeRetainedValue()
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Content-Length" as CFString, String(messageData.count) as CFString)
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Buffer-Width" as CFString, String(width) as CFString)
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Buffer-Height" as CFString, String(height) as CFString)
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Buffer-Orientation" as CFString, String(orientation) as CFString)

        CFHTTPMessageSetBody(httpResponse, messageData as CFData)

        let serializedMessage = CFHTTPMessageCopySerializedMessage(httpResponse)?.takeRetainedValue() as Data?

        return serializedMessage
    }

    func jpegData(from buffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer)

        if #available(iOS 17.0, *) {
            return Self.imageContext.jpegRepresentation(
                of: image,
                colorSpace: Self.colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionQuality]
            )
        } else {
            // Workaround for "unsupported file format 'public.heic'"
            guard let cgImage = Self.imageContext.createCGImage(image, from: image.extent) else {
                return nil
            }

            let data = NSMutableData()
            guard let imageDestination = CGImageDestinationCreateWithData(data, AVFileType.jpg as CFString, 1, nil) else {
                return nil
            }

            let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
            CGImageDestinationAddImage(imageDestination, cgImage, options as CFDictionary)

            guard CGImageDestinationFinalize(imageDestination) else {
                return nil
            }

            return data as Data
        }
    }
}

#endif
