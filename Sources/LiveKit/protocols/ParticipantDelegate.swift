//
//  File.swift
//  
//
//  Created by David Zhao on 3/25/21.
//

import Foundation

/// delegate methods for a participant.
///
/// You can set `Participant.delegate` on each participant. All delegate methods are optional
/// To ensure each participant's delegate is registered, you can look through `Room.localParticipant` and `Room.remoteParticipants` on connect
/// and register it on new participants inside `RoomDelegate.participantDidConnect`
public protocol ParticipantDelegate {
    // all participants
    /// Participant's metadata has been changed
    func metadataDidChange(participant: Participant)
    
    /// The isSpeaking status of the participant has changed
    func isSpeakingDidChange(participant: Participant)
    
    /// The participant was muted.
    ///
    /// For the local participant, the callback will be called if setMute was called on LocalTrackPublication,
    /// or if the server has requested the participant to be muted
    func didMute(publication: TrackPublication, participant: Participant)
    
    /// The participant was unmuted.
    ///
    /// For the local participant, the callback will be called if setMute was called on LocalTrackPublication,
    /// or if the server has requested the participant to be unmuted
    func didUnmute(publication: TrackPublication, participant: Participant)
    
    // remote participants
    /// When a new track is published to room after the local participant has joined.
    ///
    /// It will not fire for tracks that are already published
    func didPublishRemoteTrack(publication: RemoteTrackPublication, participant: RemoteParticipant)
    
    /// A RemoteParticipant has unpublished a track
    func didUnpublishRemoteTrack(publication: RemoteTrackPublication, particpant: RemoteParticipant)
    
    /// The LocalParticipant has subscribed to a new track.
    ///
    /// This event will always fire as long as new tracks are ready for use.
    func didSubscribe(track: Track, publication: RemoteTrackPublication, participant: RemoteParticipant)
    
    /// Could not subscribe to a track.
    ///
    /// This is an error state, the subscription can be retried
    func didFailToSubscribe(sid: String, error: Error, participant: RemoteParticipant)
    
    /// A subscribed track is no longer available.
    ///
    /// Clients should listen to this event and handle cleanup
    func didUnsubscribe(track: Track, publication: RemoteTrackPublication, participant: RemoteParticipant)
    
    /// Data was received on a data track
    func didReceive(data: Data, dataTrack: RemoteTrackPublication, participant: RemoteParticipant)
}

public extension ParticipantDelegate {
    func metadataDidChange(participant: Participant) {}
    func isSpeakingDidChange(participant: Participant) {}
    func didMute(publication: TrackPublication, participant: Participant) {}
    func didUnmute(publication: TrackPublication, participant: Participant)  {}
    func didPublishRemoteTrack(publication: RemoteTrackPublication, participant: RemoteParticipant) {}
    func didUnpublishRemoteTrack(publication: RemoteTrackPublication, particpant: RemoteParticipant) {}
    func didSubscribe(track: Track, publication: RemoteTrackPublication, participant: RemoteParticipant) {}
    func didFailToSubscribe(sid: String, error: Error, participant: RemoteParticipant) {}
    func didUnsubscribe(track: Track, publication: RemoteTrackPublication, participant: RemoteParticipant) {}
    func didReceive(data: Data, dataTrack: RemoteTrackPublication, participant: RemoteParticipant) {}
}
