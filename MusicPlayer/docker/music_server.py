from flask import Flask, request, send_file, jsonify
import yt_dlp
import os
import subprocess

app = Flask(__name__)
DOWNLOAD_FOLDER = "downloads"
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

def download_audio(youtube_url, output_name):
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': f'{DOWNLOAD_FOLDER}/{output_name}.%(ext)s',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'wav',
        }]
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([youtube_url])

    # Convert to DFPWM using ffmpeg
    input_wav = f"{DOWNLOAD_FOLDER}/{output_name}.wav"
    output_dfpwm = f"{DOWNLOAD_FOLDER}/{output_name}.dfpwm"
    subprocess.run(["ffmpeg", "-i", input_wav, "-f", "s16le", "-ar", "48000", "-ac", "1", output_dfpwm])
    os.remove(input_wav)  # Remove the intermediate WAV file
    return output_dfpwm

@app.route("/download", methods=["GET"])
def download():
    youtube_url = request.args.get("url")
    if not youtube_url:
        return jsonify({"error": "Missing YouTube URL"}), 400
    
    output_name = "song"
    try:
        file_path = download_audio(youtube_url, output_name)
        return send_file(file_path, as_attachment=True)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
