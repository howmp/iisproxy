CGO_ENABLED=0 GOOS=linux GOARCH=386 go build  -trimpath -ldflags "-s -w" -o dist/iisproxy32 .
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build  -trimpath -ldflags "-s -w" -o dist/iisproxy64 .
CGO_ENABLED=0 GOOS=windows GOARCH=386 go build  -trimpath -ldflags "-s -w" -o dist/iisproxy32.exe .
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build  -trimpath -ldflags "-s -w" -o dist/iisproxy64.exe .