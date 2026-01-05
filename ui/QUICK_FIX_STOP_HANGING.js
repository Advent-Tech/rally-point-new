// QUICK FIX FOR STOP TRANSMISSION HANGING
// Replace the stopTransmitting method in WalkieTalkieService.ts

async stopTransmitting() {
  try {
    console.log('🎤 Stopping audio transmission...');

    // IMMEDIATE UI UPDATE - This fixes the hanging issue
    this.state.isTransmitting = false;
    this.state.currentSpeaker = null;
    this.state.currentSpeakerName = null;
    this.notifyStateChange();
    console.log('✅ UI state updated immediately');

    // Store session info before clearing
    const sessionId = this.state.sessionId;
    const isLocalSession = sessionId?.startsWith('local-');

    // Clear session immediately
    this.currentSession = null;
    this.state.sessionId = null;

    // Handle audio cleanup in background (non-blocking)
    setTimeout(async () => {
      try {
        // Stop audio recording
        if (this.audioRecording) {
          await this.audioRecording.stopAndUnloadAsync();
          this.audioRecording = null;
        }

        // Only update Firestore for real sessions (not local ones)
        if (sessionId && !isLocalSession) {
          try {
            await updateDoc(doc(db, 'walkie_talkie_sessions', sessionId), {
              isActive: false,
              endedAt: serverTimestamp(),
            });
            console.log('✅ Session updated in background');
          } catch (error) {
            console.warn('⚠️ Background session update failed:', error);
          }
        } else {
          console.log('ℹ️ Local session - no Firestore update needed');
        }
      } catch (error) {
        console.warn('⚠️ Background cleanup error:', error);
      }
    }, 100); // Small delay to ensure UI updates first

    console.log('✅ Audio transmission stopped successfully');
  } catch (error) {
    console.error('❌ Error stopping audio transmission:', error);
  }
}

// ALSO ADD THIS METHOD:
handleAudioStopInBackground(sessionId) {
  // This method is called from the corrupted code
  // Just do basic cleanup
  setTimeout(() => {
    if (this.audioRecording) {
      this.audioRecording.stopAndUnloadAsync().catch(console.warn);
      this.audioRecording = null;
    }
  }, 100);
}
