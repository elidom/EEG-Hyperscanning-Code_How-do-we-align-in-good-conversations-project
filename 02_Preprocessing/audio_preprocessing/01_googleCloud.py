# -------------------------------------------------------------------------
#  AUDIO PREPROCESSING PIPELINE (Step 01) 
#  TRANSCRIPTION USING GOOGLE CLOUD SPEECH-TO-TEXT (V2)
#
#  Author: Peter C.H. Lam
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#
#  Transcribes WAV files located in a specified
#  Google Cloud Storage (GCS) folder using Google Cloud Speech-to-Text V2.
#
# -------------------------------------------------------------------------


import os
from google.cloud import storage
from google.api_core.client_options import ClientOptions
from google.cloud.speech_v2 import SpeechClient
from google.cloud.speech_v2.types import cloud_speech

# --- Configuration ---
GCS_INPUT_BUCKET = "hypscanaudstoring"
GCS_INPUT_PREFIX = "00_Clean_Audio_Files/dyad15 (broken Stimtrack)/" # IMPORTANT: Ensure this ends with a slash
GCS_OUTPUT_FOLDER = "gs://hypscantry1/transcripts"
PROJECT_ID = "hypscanspeechtrans"
LOCATION = "us-central1"
MAX_AUDIO_LENGTH_SECS = 8 * 60 * 60 # Max timeout for a single audio file (8 hours)

def transcribe_gcs_folder():
    """
    Lists all WAV files in a specified GCS folder and initiates a batch transcription
    job for each using Google Cloud Speech-to-Text V2.
    """
    storage_client = storage.Client()
    speech_client = SpeechClient(
        client_options=ClientOptions(
            api_endpoint=f"{LOCATION}-speech.googleapis.com",
        ),
    )

    # Get the bucket object
    bucket = storage_client.bucket(GCS_INPUT_BUCKET)

    # List blobs with the specified prefix
    # The prefix should include the "folder" path
    blobs = bucket.list_blobs(prefix=GCS_INPUT_PREFIX)

    print(f"Searching for WAV files in gs://{GCS_INPUT_BUCKET}/{GCS_INPUT_PREFIX}...")
    found_files = []
    for blob in blobs:
        # Check if it's a WAV file and not a directory placeholder
        if blob.name.endswith(".wav") and not blob.name.endswith("/"):
            found_files.append(f"gs://{GCS_INPUT_BUCKET}/{blob.name}")

    if not found_files:
        print(f"No WAV files found in gs://{GCS_INPUT_BUCKET}/{GCS_INPUT_PREFIX}. Please check the path and file extensions.")
        return

    print(f"Found {len(found_files)} WAV files. Initiating transcription jobs...")

    for audio_file_uri in found_files:
        print(f"\n--- Initiating transcription for: {audio_file_uri} ---")

        config = cloud_speech.RecognitionConfig(
            explicit_decoding_config=cloud_speech.ExplicitDecodingConfig(
                encoding="LINEAR16",
                sample_rate_hertz=44100,
                audio_channel_count=1
            ),
            features=cloud_speech.RecognitionFeatures(
                enable_word_confidence=True,
                enable_word_time_offsets=True,
                multi_channel_mode=cloud_speech.RecognitionFeatures.MultiChannelMode.SEPARATE_RECOGNITION_PER_CHANNEL,
            ),
            model="chirp_2",
            language_codes=["en-US"],
        )

        output_config = cloud_speech.RecognitionOutputConfig(
            gcs_output_config=cloud_speech.GcsOutputConfig(uri=GCS_OUTPUT_FOLDER),
        )

        files = [cloud_speech.BatchRecognizeFileMetadata(uri=audio_file_uri)]

        request = cloud_speech.BatchRecognizeRequest(
            recognizer=f"projects/{PROJECT_ID}/locations/{LOCATION}/recognizers/_",
            config=config,
            files=files,
            recognition_output_config=output_config,
        )

        try:
            operation = speech_client.batch_recognize(request=request)
            print(f"Transcription operation started. Operation name: {operation.operation.name}")
            # Note: This script initiates the operations but doesn't wait for them to complete.
            # Batch recognition is an asynchronous operation. You'll need to check the
            # status of each operation separately if you need to know when they finish.
            # For example, you can store operation.operation.name and poll it later.
            # If you uncomment the line below, the script will wait for each transcription
            # to complete sequentially, which might take a very long time for many files.
            # response = operation.result(timeout=3 * MAX_AUDIO_LENGTH_SECS)
            # print(f"Transcription for {audio_file_uri} completed. Response: {response}")
        except Exception as e:
            print(f"ERROR: Failed to initiate transcription for {audio_file_uri}: {e}")

    print("\nAll available transcription operations have been initiated.")
    print(f"Results will be written to: {GCS_OUTPUT_FOLDER}")
    print("You can monitor the operations in the Google Cloud Console or using 'gcloud speech operations list'.")

if __name__ == "__main__":
    transcribe_gcs_folder()
