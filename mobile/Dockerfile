FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /workspace/mobile

ENV PUB_CACHE=/workspace/.pub-cache

CMD ["sh", "-lc", "flutter pub get && flutter analyze && flutter test"]
