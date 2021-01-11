##!/bin/bash

PATH_TO_YAML_FILE="${1}"
PATH_TO_ENV_FILE="${2}"
LINE_INDENTATION=2 # In spaces.

# Todo: replace KEY_OPEN with KEY_INLINE_VALUE ?

# Line types:
# 1 = Comment line. Line that starts with a hashtag.
# 2 = Key line. Line that starts with value followed by a colon. The key could also contain a value on the same line.
# 3 = Value line. Any other line that contains a value, but didn't match any of the previous line types..
function handleLine() {
#  handleMultiLine
  handleArrayLineType1
#  handleArrayLineType2
  handleKeyLine
#  handleCommentLine
}

# Handle arrays with the format: ['value 1', 'value 2']
function handleArrayLineType1() {
  if [[ ${CURRENT_LINE_HANDLED} -eq 1 || -n "${MULTI_LINE_OPEN}" || -n "${ARRAY_TYPE_2_OPEN}" ]]; then
    return
  fi

  if [[ "$(perl -nle 'if (/^.*?:[[:space:]]+\[/) { print $&; exit }' <<< "${CURRENT_LINE}")" && -z "${ARRAY_TYPE_1_OPEN}" ]]; then
    KEY="$(echo "${CURRENT_LINE}" | perl -nle "print $& if m{^.*?:[[:space:]]+}" | perl -pe "s/:[[:space:]]$//")"
    VALUE="$(echo "${CURRENT_LINE}" | perl -nle "print $& if m{:[[:space:]]+.*$}" | perl -pe "s/^:[[:space:]]//")"
    NAMESPACES+=("${KEY}")
#    KEY_OPEN=1
    KEY_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
#  echo "${KEY}"
#  echo "${VALUE}"
##  echo "${CURRENT_LINE}"
#  exit

#    ARRAY_OPEN=1
    ARRAY_TYPE_1_OPEN=1
    ARRAY_VALUE=()
    ARRAY_INLINE=1
#    setKeyValue
  elif [[ "$(perl -nle'if (/^[[:space:]]*\[/) { print $&; exit }' <<< "${CURRENT_LINE}")" && -z "${ARRAY_TYPE_1_OPEN}" ]]; then
#    ARRAY_OPEN=1
    ARRAY_TYPE_1_OPEN=1
    ARRAY_VALUE=()
  elif [[ ARRAY_TYPE_1_OPEN -eq 0 ]]; then
    return
  fi

  if [[ ARRAY_TYPE_1_OPEN -eq 1 ]]; then
    if [[ ARRAY_INLINE -eq 1 ]]; then
      REPLACED_LINE="$(echo "${CURRENT_LINE}" | perl -pe "s/^.*?[[:space:]]+\[//" | perl -pe "s/\][[:space:]]*$//")"
    else
      REPLACED_LINE="$(echo "${CURRENT_LINE}" | perl -pe "s/^[[:space:]]*\[//" | perl -pe "s/\][[:space:]]*$//" )"
    fi

    IFS=','; for EXPLODED_ITEM in ${REPLACED_LINE}; do
      ARRAY_VALUE+=("$(trim "${EXPLODED_ITEM}")")
    done
  fi

  # reset variables as soon as we find the next key or end of document has been reached
  # @todo add end of document check
  if [[ ARRAY_TYPE_1_OPEN -eq 1 && "${NEXT_LEADING_SPACES}" -le "${KEY_LEADING_SPACES}" ]]; then
    if (( ${#ARRAY_VALUE[@]} )); then
      local i
      for (( i = 0; i < ${#ARRAY_VALUE[*]}; ++ i )); do
        writeValueToNamespace "${ARRAY_VALUE[$i]}" "${i}"
      done
    fi

    NAMESPACES=()

#    unset ARRAY_OPEN
    unset ARRAY_TYPE_1_OPEN
    unset ARRAY_VALUE
    resetKeyValue
#    unset ARRAY_INLINE
  fi

  CURRENT_LINE_HANDLED=1
}

function handleArrayLineType2() {
  if [[ ${CURRENT_LINE_HANDLED} -eq 1 || -n "${MULTI_LINE_OPEN}" || -n "${ARRAY_TYPE_1_OPEN}" ]]; then
    return
  fi

  if [[ "${CURRENT_LINE}" =~ ^[[:space:]]*- ]]; then
      echo "array type 2 ${CURRENT_LINE}"
  fi
}

function handleMultiLine() {
  if [[ ${CURRENT_LINE_HANDLED} -eq 1 || -n "${ARRAY_TYPE_1_OPEN}" || -n "${ARRAY_TYPE_2_OPEN}" ]]; then
    return
  fi

  if [[ "${CURRENT_LINE}" =~ ^[[:space:]]*[^\']+:[[:space:]]*\| ]]; then
      MULTI_LINE_OPEN=1
      MULTI_LINE_LINEBREAK_END=0
  fi
}

function handleCommentLine() {
  if [[ ${CURRENT_LINE_HANDLED} -eq 1 || -n "${ARRAY_TYPE_1_OPEN}" || -n "${ARRAY_TYPE_2_OPEN}" || -n "${MULTI_LINE_OPEN}" ]]; then
    return
  fi

  if [[ "${CURRENT_LINE}" =~ ^[[:space:]]*# ]]; then
    echo "comment ${CURRENT_LINE}"
  fi
}

function handleKeyLine() {
  if [[ ${CURRENT_LINE_HANDLED} -eq 1 || -n "${ARRAY_TYPE_1_OPEN}" || -n "${ARRAY_TYPE_2_OPEN}" || -n "${MULTI_LINE_OPEN}" ]]; then
    return
  fi

  if [[ "$(perl -nle 'if (/^.*?:/) { print $&; exit }' <<< "${CURRENT_LINE}")" ]]; then
    if [[ -n ${KEY_LEADING_SPACES} && "${CURRENT_LEADING_SPACES}" -le "${KEY_LEADING_SPACES}" && -n "${CURRENT_LINE}" ]]; then
      writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"
      resetNamespace "${CURRENT_LEADING_SPACES}"
      resetKeyValue
    fi

    KEY="$(echo "${CURRENT_LINE}" | perl -nle "print $& if m{^.*?:([[:space:]]+)?}" | perl -pe "s/:[[:space:]]$//")"
    VALUE="$(echo "${CURRENT_LINE}" | perl -nle "print $& if m{:[[:space:]]+.*$}" | perl -pe "s/^:[[:space:]]//")"
    NAMESPACES+=("${KEY}")
    KEY_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
  fi
}

#function determineValueType() {
#  if [[ "${1}" =~ ^[[:space:]]*# ]]; then
#    echo
#  fi
#}

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

#function setKeyValue() {
#  KEY="$(echo "${CURRENT_LINE}" | grep -oP "^.*?:" | perl -pe "s/:[[:space:]]$//")"
#  VALUE="$(echo "${CURRENT_LINE}" | grep -oP ":[[:space:]]+.*$" | perl -pe "s/^:[[:space:]]//")"
#  KEY="$(echo "${CURRENT_LINE}" | grep -oP "^.*?:[[:space:]]+" | perl -pe "s/:[[:space:]]$//")"
#  VALUE="$(echo "${CURRENT_LINE}" | grep -oP ":[[:space:]]+.*$" | perl -pe "s/^:[[:space:]]//")"
#  NAMESPACES+=("${KEY}")
#  KEY_OPEN=1
#  KEY_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
#}

function resetKeyValue() {
  unset KEY
  unset VALUE
#  unset KEY_OPEN
  unset KEY_LEADING_SPACES
}

function countLeadingSpaces() {
  awk -F'[^ ]' '{print length($1)}' <<< "${1}"
}

function removeLeadingSpaces() {
  if [ -n "${2}" ]; then
    echo -e "${1}" | perl -pe "s/^[[:space:]]\{${2}\}//"
  else
    echo -e "${1}" | perl -pe "s/^[[:space:]]*//"
  fi
}

function replaceNonAlphanumericWithUnderscore() {
  echo -e "${1}" | perl -lpe "s/[^a-zA-Z0-9]/_/g"
}

#function replaceSpaceWithUnderscore() {
#  echo "${1// /_}"
#}

function capitalize() {
  echo "${1^^}"
}

function trim() {
  echo -e "${1}" | perl -pe 's/^[[:space:]]*//' | perl -pe 's/[[:space:]]*$//'
}

function resetNamespace() {
  RESET_TO_INDENTATION="${1}"
  INDEX="$((RESET_TO_INDENTATION / LINE_INDENTATION))"
  NAMESPACES=("${NAMESPACES[@]:0:${INDEX}}")
}

function formatNamespace() {
  local NAMESPACE=""
  NAMESPACE="$(removeLeadingSpaces "${1}")"
  NAMESPACE="$(replaceNonAlphanumericWithUnderscore "${NAMESPACE}")"
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
    CURRENT_LINE_HANDLED=0
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