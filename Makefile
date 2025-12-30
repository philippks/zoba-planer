.PHONY: build dev

build:
	elm make src/Main.elm --output=main.js

dev:
	elm-live src/Main.elm --hot -- --output=main.js
