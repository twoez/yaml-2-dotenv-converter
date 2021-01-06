##!/bin/bash

PATH_TO_YAML_FILE="${1}"
PATH_TO_ENV_FILE="${2}"
LINE_INDENTATION=2 # In spaces.

# Line types:
# 1 = Comment line. Line that starts with a hashtag.
# 2 = Key line. Line that starts with value followed by a colon. The key could also contain a value on the same line.
# 3 = Value line. Any other line that contains a value, but didn't match any of the previous line types..
function determineLineType() {
  if [[ "${1}" =~ ^[[:space:]]*# && MULTILINE_OPEN -eq 0 && ARRAY_OPEN -eq 0 ]]; then
    echo 1
  elif [[ "${1}" =~ ^[[:space:]]*[^\']+: && MULTILINE_OPEN -eq 0 && ARRAY_OPEN -eq 0 ]]; then
    echo 2
  else
    echo 3
  fi
}

function handleKeyLine() {
  IFS=':' read -r KEY VALUE <<< "${CURRENT_LINE}"
  NAMESPACES+=("${KEY}")
  KEY_OPEN=1
  START_CHARACTER=""

  if [[ "${NEXT_LEADING_SPACES}" != "${CURRENT_LEADING_SPACES}" ]]; then
#    if [[ "${CURRENT_LINE}" =~ ^[[:space:]]*[^\']+:[[:space:]]*\|[-0-9]+ ]]; then
#      MULTILINE_OPEN=1
#      MULTILINE_LINEBREAK_END=1
    if [[ "${CURRENT_LINE}" =~ ^[[:space:]]*[^\']+:[[:space:]]*\| ]]; then
      MULTILINE_OPEN=1
      MULTILINE_LINEBREAK_END=0
    elif [[ "${NEXT_LINE}" =~ ^[[:space:]]*- ]]; then
      ARRAY_OPEN=1
    elif [[ "${NEXT_LEADING_SPACES}" -lt "${CURRENT_LEADING_SPACES}" ]]; then
      writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"
      resetNamespace "${NEXT_LEADING_SPACES}"
    elif [[ -z "${NEXT_LINE}" ]]; then
      writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"
    fi
  else
    writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"

    if [[ "${NEXT_LEADING_SPACES}" -eq 0 ]]; then
      NAMESPACES=()
    fi

    resetNamespace "${CURRENT_LEADING_SPACES}"
  fi
}

function handleValueLine() {
  if [[ "${MULTILINE_OPEN}" -eq 1 ]]; then
    if [[ -n "${CURRENT_LINE}" && -z "${MULTILINE_LEADING_SPACES}" ]]; then
      MULTILINE_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
    fi

    MULTILINE_VALUE+="$(removeLeadingSpaces "${CURRENT_LINE}" "${MULTILINE_LEADING_SPACES}")"

    if [[ "${MULTILINE_LINEBREAK_END}" -eq 1 ]]; then
      MULTILINE_VALUE+="\n"
    fi

    if [[ "${NEXT_LEADING_SPACES}" -lt "${MULTILINE_LEADING_SPACES}" ]]; then
      writeValueToNamespace "${MULTILINE_VALUE}"
      unset MULTILINE_OPEN
      unset MULTILINE_LINEBREAK_END
      unset MULTILINE_VALUE
      unset MULTILINE_LEADING_SPACES
    fi
  elif [[ "${ARRAY_OPEN}" -eq 1 ]]; then
    ARRAY_VALUE+=("$(convertArrayValue "${CURRENT_LINE}")")

    if [[ "${NEXT_LEADING_SPACES}" -lt "${CURRENT_LEADING_SPACES}" ]]; then
      if (( ${#ARRAY_VALUE[@]} )); then
        local i
        for (( i = 0; i < ${#ARRAY_VALUE[*]}; ++ i )); do
          writeValueToNamespace "${ARRAY_VALUE[$i]}" "${i}"
        done
      fi

      unset ARRAY_OPEN
      unset ARRAY_VALUE
    fi
  fi

  if [[ "${NEXT_LEADING_SPACES}" -lt "${CURRENT_LEADING_SPACES}" ]]; then
    if [[ "${NEXT_LEADING_SPACES}" -ge "${LINE_INDENTATION}" ]]; then
      resetNamespace "${NEXT_LEADING_SPACES}"
    else
      NAMESPACES=()
    fi
  fi
}

function handleCommentLine() {
  writeValue "$(removeLeadingSpaces "${CURRENT_LINE}")"
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

function countLeadingSpaces() {
  awk -F'[^ ]' '{print length($1)}' <<< "${1}"
}

function removeLeadingSpaces() {
  if [ -n "${2}" ]; then
    echo -e "${1}" | sed -e "s/^[[:space:]]\{${2}\}//"
  else
    echo -e "${1}" | sed -e "s/^[[:space:]]*//"
  fi
}

function replaceSpaceWithUnderscore() {
  echo "${1// /_}"
}

function convertArrayValue() {
  echo -e "${1}" | sed -e 's/^[[:space:]]*\-[[:space:]]*//'
}

function capitalize() {
  echo "${1^^}"
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

#ARRAY_OPEN=0
#ARRAY_VALUE=()
#MULTILINE_OPEN=0
#MULTILINE_LINEBREAK_END=0
#MULTILINE_VALUE=""
#NEXT_LEADING_SPACES=0
NAMESPACES=()

if (( ${#LINES[@]} )); then
  for (( i = 0; i < ${#LINES[*]}; ++ i )); do
    CURRENT_LINE="${LINES[$i]}"
    CURRENT_LEADING_SPACES="$(countLeadingSpaces "${LINES[$i]}")"
    CURRENT_LINE_TYPE="$(determineLineType "${CURRENT_LINE}")"
    NEXT_LINE="${LINES[$i+1]}"
    NEXT_LEADING_SPACES="$(countLeadingSpaces "${LINES[$i+1]}")"

    if [[ "${CURRENT_LINE_TYPE}" -eq 1 ]]; then
      handleCommentLine
    elif [[ "${CURRENT_LINE_TYPE}" -eq 2 ]]; then
      handleKeyLine
    elif [[ "${CURRENT_LINE_TYPE}" -eq 3 ]]; then
      handleValueLine
    fi
  done
fi
