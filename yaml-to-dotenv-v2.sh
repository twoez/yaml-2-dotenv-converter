##!/bin/bash

PATH_TO_YAML_FILE="${1}"
PATH_TO_ENV_FILE="${2}"
LINE_INDENTATION=2 # In spaces.

# Line types:
# 1 = Comment line. Line that starts with a hashtag.
# 2 = Key line. Line that starts with value followed by a colon. The key could also contain a value on the same line.
# 3 = Value line. Any other line that contains a value, but didn't match any of the previous line types..
function handleLine() {
  if [[ "${CURRENT_LINE}" =~ ^[[:space:]]*# && MULTILINE_OPEN -eq 0 && ARRAY_OPEN -eq 0 && KEY_OPEN -ne 1 ]]; then
    echo 1
  elif [[ "${CURRENT_LINE}" =~ ^[[:space:]]*.*: && MULTILINE_OPEN -eq 0 && ARRAY_OPEN -eq 0 && KEY_OPEN -ne 1 ]]; then
    IFS=':' read -r KEY VALUE <<< "${CURRENT_LINE}"
    #  NAMESPACES+=("${KEY}")
    KEY_OPEN=1
    KEY_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
  elif [[ "${CURRENT_LINE}" =~ ^[[:space:]]*.*: && MULTILINE_OPEN -eq 0 && ARRAY_OPEN -eq 0 && KEY_OPEN -eq 1 && KEY_LEADING_SPACES -lt CURRENT_LEADING_SPACES ]]; then

    echo "${CURRENT_LINE}"
    KEY_OPEN=0
    exit
  elif [[ KEY_OPEN -eq 1 ]]; then
    echo 3
  fi
}

#function determineValueType() {
#  echo "hi"
#}
#
#function handleKeyLine() {
#  IFS=':' read -r KEY VALUE <<< "${CURRENT_LINE}"
##  NAMESPACES+=("${KEY}")
#  KEY_OPEN=1
##  echo "${CURRENT_LINE}"
##  KEY_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
##  START_CHARACTER=""
#}
#
#function handleValueLine() {
#  echo ""
#}
#
#function handleCommentLine() {
#  echo ""
#}

function countLeadingSpaces() {
  awk -F'[^ ]' '{print length($1)}' <<< "${1}"
}

function resetNamespace() {
  RESET_TO_INDENTATION="${1}"
  INDEX="$((RESET_TO_INDENTATION / LINE_INDENTATION))"
  NAMESPACES=("${NAMESPACES[@]:0:${INDEX}}")
}

function formatNamespace() {
  local NAMESPACE=""
  NAMESPACE="$(removeLeadingSpaces "${1}")"
  NAMESPACE="$(replaceSpaceWithUnderscore "${NAMESPACE}")"
  NAMESPACE="$(capitalize "${NAMESPACE}")"
  echo "${NAMESPACE}"
}

function writeValueToNamespace() {
  local NAMESPACE_STRING=""
  if (( ${#NAMESPACES[@]} )); then
    for NAMESPACE in "${NAMESPACES[@]}"; do
      if [ -n "${NAMESPACE_STRING}" ]; then
        NAMESPACE_STRING+="_"
      fi

      NAMESPACE_STRING+="$(formatNamespace "${NAMESPACE}")"
    done
  fi

  if [ -n "${2}" ]; then
    writeValue "${1}" "${NAMESPACE_STRING}[${2}]"
  else
    writeValue "${1}" "${NAMESPACE_STRING}"
  fi
}

function writeValue() {
  if [ -z "${2+x}" ]; then
    echo "${1}" >> "${PATH_TO_ENV_FILE}"
  else
    echo "${2}=${1}" >> "${PATH_TO_ENV_FILE}"
#    echo "${2}=$(printf "%q" "${1}")" >> "${PATH_TO_ENV_FILE}"
  fi
}

rm -f  "${PATH_TO_ENV_FILE}"
mapfile -t LINES < "${PATH_TO_YAML_FILE}"

if (( ${#LINES[@]} )); then
  for (( i = 0; i < ${#LINES[*]}; ++ i )); do
    CURRENT_LINE="${LINES[$i]}"
    CURRENT_LEADING_SPACES="$(countLeadingSpaces "${LINES[$i]}")"
#    CURRENT_TYPE="$(determineLineType "${CURRENT_LINE}")"
    NEXT_LINE="${LINES[$i+1]}"
    NEXT_LEADING_SPACES="$(countLeadingSpaces "${LINES[$i+1]}")"

#echo "${CURRENT_TYPE}_${CURRENT_LINE}"

    handleLine
#    if [[ "${CURRENT_TYPE}" -eq 1 ]]; then
#      handleCommentLine
#    elif [[ "${CURRENT_TYPE}" -eq 2 ]]; then
#      handleKeyLine
#    elif [[ "${CURRENT_TYPE}" -eq 3 ]]; then
#      handleValueLine
#    fi

    PREVIOUS_LINE="${CURRENT_LINE}"
    PREVIOUS_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
  done
fi