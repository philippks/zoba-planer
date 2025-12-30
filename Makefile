.PHONY: build dev

dev:
	elm-live src/Main.elm --hot -- --output=main.js
