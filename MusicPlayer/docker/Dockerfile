FROM python:3.9

# Install dependencies
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy required files
COPY music_server.py requirements.txt ./

# Install Python dependencies
RUN pip install -r requirements.txt

# Expose the Flask port
EXPOSE 5000

# Run the server
CMD ["python", "music_server.py"]
