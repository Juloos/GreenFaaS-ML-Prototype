FROM openwhisk/action-python-v3.9

# Set the working directory
WORKDIR /app

# Update apt-get and install necessary dependencies, including ffmpeg
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*
 
    
RUN pip install python-swiftclient
 