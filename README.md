# Yaml 2 dotenv converter
Bash script that converts a yaml to a dotenv.
This script uses the prettify option of the YQ yaml processor before converting.

## Usage
```
bash yaml-to-dotenv.sh "path-to-yaml/foo.yml" "path-to-dotenv/.env"
```

## Requirements
- YQ (https://github.com/mikefarah/yq)
