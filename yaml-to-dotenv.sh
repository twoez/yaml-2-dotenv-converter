##!/bin/bash

PATH_TO_YAML_FILE="${1}"
PATH_TO_ENV_FILE="${2}"
LINE_INDENTATION=4 # In spaces.

function determineLineType() {
  if [[ "${1}" =~ ^[[:space:]]*# ]]; then
    # Comment line
    echo 1
  elif [[ "${1}" =~ ^[[:space:]]*[^\']+: ]]; then
    # Variable line
    echo 2
  else
    # Value line
    echo 3
  fi
}

function typeVariable() {
  IFS=':' read -r KEY VALUE <<< "${1}"
  NAMESPACES+=("${KEY}")

  if [[ "${NEXT_LEADINGSPACES}" != "${CURRENT_LEADINGSPACES}" ]]; then
    if [[ "${1}" =~ ^[[:space:]]*[^\']+:[[:space:]]*\|- ]]; then
      VARIABLE_MULTILINE_OPEN=1
      VARIABLE_MULTILINE_LINEBREAK_END=1
    elif [[ "${1}" =~ ^[[:space:]]*[^\']+:[[:space:]]*\| ]]; then
      VARIABLE_MULTILINE_OPEN=1
      VARIABLE_MULTILINE_LINEBREAK_END=0
    elif [[ "${NEXT_LINE}" =~ ^[[:space:]]*- ]]; then
      VARIABLE_ARRAY_OPEN=1
    elif [[ "${NEXT_LEADINGSPACES}" -lt "${CURRENT_LEADINGSPACES}" ]]; then
      writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"
      resetNamespace "${NEXT_LEADINGSPACES}"
    elif [[ -z "${NEXT_LINE}" ]]; then
      writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"
    fi

    VARIABLE_LEADING_SPACES="${CURRENT_LEADINGSPACES}"
  else
    writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"

    if [[ "${NEXT_LEADINGSPACES}" -eq 0 ]]; then
      NAMESPACES=()
    fi

    resetNamespace "${CURRENT_LEADINGSPACES}"
  fi
}

function typeValue() {
  if [[ "${VARIABLE_MULTILINE_OPEN}" -eq 1 ]]; then
    VARIABLE_MULTILINE_VALUE+="$(removeLeadingSpaces "${1}")"

    if [[ "${NEXT_LEADINGSPACES}" != "${VARIABLE_LEADING_SPACES}" ]] || [[ "${VARIABLE_MULTILINE_LINEBREAK_END}" -eq 1 ]]; then
      VARIABLE_MULTILINE_VALUE+="\n"
    fi
  elif [[ "${VARIABLE_ARRAY_OPEN}" -eq 1 ]]; then
    VARIABLE_ARRAY_VALUE+=("$(convertArrayValue "${1}")")
  fi

  if [[ "${NEXT_LEADINGSPACES}" == "${VARIABLE_LEADING_SPACES}" ||
    ("${NEXT_LEADINGSPACES}" -lt "${CURRENT_LEADINGSPACES}" && "$(determineLineType "${NEXT_LINE}")" -eq 2) ]]; then
    if [[ "${VARIABLE_MULTILINE_OPEN}" -eq 1 ]]; then
      writeValueToNamespace "${VARIABLE_MULTILINE_VALUE}"
    elif [[ "${VARIABLE_ARRAY_OPEN}" -eq 1 ]]; then
      if (( ${#VARIABLE_ARRAY_VALUE[@]} )); then
        local i
        for (( i = 0; i < ${#VARIABLE_ARRAY_VALUE[*]}; ++ i )); do
          writeValueToNamespace "${VARIABLE_ARRAY_VALUE[$i]}" "${i}"
        done
      fi
    fi

    VARIABLE_ARRAY_OPEN=0
    VARIABLE_ARRAY_VALUE=()
    VARIABLE_MULTILINE_OPEN=0
    VARIABLE_MULTILINE_LINEBREAK_END=0
    VARIABLE_MULTILINE_VALUE=""
    VARIABLE_LEADING_SPACES=0

    if [[ "${NEXT_LEADINGSPACES}" -ge "${LINE_INDENTATION}" ]]; then
      resetNamespace "${NEXT_LEADINGSPACES}"
    else
      NAMESPACES=()
    fi
  fi
}

function typeComment() {
  writeValue "$(removeLeadingSpaces "${1}")"
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
  echo -e "${1}" | sed -e 's/^[[:space:]]*//'
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
        NAMESPACE_STRING+="_$(formatNamespace "${NAMESPACE}")"
      else
        NAMESPACE_STRING+="$(formatNamespace "${NAMESPACE}")"
      fi
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
    echo "${2}=$(printf "%q" "${1}")" >> "${PATH_TO_ENV_FILE}"
  fi
}

rm -f  "${PATH_TO_ENV_FILE}"
mapfile -t LINES < <(yq r --prettyPrint -I"${LINE_INDENTATION}" "${PATH_TO_YAML_FILE}")

VARIABLE_ARRAY_OPEN=0
VARIABLE_ARRAY_VALUE=()
VARIABLE_MULTILINE_OPEN=0
VARIABLE_MULTILINE_LINEBREAK_END=0
VARIABLE_MULTILINE_VALUE=""
VARIABLE_LEADING_SPACES=0
VARIABLE_PARENT_NAMESPACE=''
NEXT_LEADINGSPACES=0
NAMESPACES=()

if (( ${#LINES[@]} )); then
  for (( i = 0; i < ${#LINES[*]}; ++ i )); do
    CURRENT_LINE="${LINES[$i]}"
    CURRENT_LEADINGSPACES="$(countLeadingSpaces "${LINES[$i]}")"
    CURRENT_LINE_TYPE="$(determineLineType "${CURRENT_LINE}")"
    NEXT_LINE="${LINES[$i+1]}"
    NEXT_LEADINGSPACES="$(countLeadingSpaces "${LINES[$i+1]}")"

    if [[ "${CURRENT_LINE_TYPE}" -eq 1 ]]; then
      typeComment "${CURRENT_LINE}"
    elif [[ "${CURRENT_LINE_TYPE}" -eq 2 ]]; then
      typeVariable "${CURRENT_LINE}"
    elif [[ "${CURRENT_LINE_TYPE}" -eq 3 ]]; then
      typeValue "${CURRENT_LINE}"
    fi
  done
fi
