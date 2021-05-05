##!/bin/bash

PATH_TO_YAML_FILE="${1}"
PATH_TO_ENV_FILE="${2}"
LINE_INDENTATION=2 # In spaces.

# Line types:
# 1 = Comment line. Line that starts with a hashtag.
# 2 = Key line. Line that starts with value followed by a colon. The key could also contain a value on the same line.
# 3 = Value line. Any other line that contains a value, but didn't match any of the previous line types..
function handleLine() {
  handleLineTypeKey
#  handleMultiLine
  handleLineTypeArray1
#  handleArrayLineType2
#  handleValueLine
#  handleKeyLine
#  handleCommentLine

  if [[ -n "${CURRENT_LINE}" && ${CURRENT_LINE_HANDLED} -eq 0 ]]; then
    echo "could not proces line ${CURRENT_LINE}"
    exit
  fi

}

function handleLineTypeKey() {
  if [[ -n "${LINE_TYPE_MULTI_OPEN}" || -n "${LINE_TYPE_ARRAY_1_OPEN}" || -n "${LINE_TYPE_ARRAY_2_OPEN}" || -n "${LINE_TYPE_VALUE_OPEN}" ]]; then
    return
  fi

  # perl -nle "print $& if m{^.*?:($|[[:space:]]+)}" -> line ends with ":" or line ends with ":" followed by a space
  if [[ "$(perl -nle 'if (/^.*?:($|[[:space:]]+)/) { print $&; exit }' <<< "${CURRENT_LINE}")" ]]; then
    if [[ -n ${KEY_LEADING_SPACES} && "${CURRENT_LEADING_SPACES}" -le "${KEY_LEADING_SPACES}" ]]; then
#      writeValueToNamespace "$(removeLeadingSpaces "${VALUE}")"
      resetNamespace "${CURRENT_LEADING_SPACES}"
      reset
    fi

    # perl -pe "s/:[[:space:]]$//" -> replace everything after the latest ":" including spaces
    KEY="$(echo "${CURRENT_LINE}" | perl -nle "print $& if m{^.*?:($|[[:space:]]+)}" | perl -pe "s/:[[:space:]]*$//")"
    NAMESPACES+=("${KEY}")
    KEY_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
#    echo ${NAMESPACES[*]}

    if [[ "$(perl -nle 'if (/^.*?:$/) { print $&; exit }' <<< "${CURRENT_LINE}")" ]]; then
      CURRENT_LINE_HANDLED=1
    fi
  fi
}

function handleLineTypeArray1() {
  if [[ ${CURRENT_LINE_HANDLED} -eq 1 || -n "${LINE_TYPE_MULTI_OPEN}" || -n "${LINE_TYPE_ARRAY_2_OPEN}" || -n "${LINE_TYPE_VALUE_OPEN}" ]]; then
    return
  fi

  if [[ "$(perl -nle 'if (/^.*?:[[:space:]]+\[/) { print $&; exit }' <<< "${CURRENT_LINE}")" && -z "${LINE_TYPE_ARRAY_1_OPEN}" ]]; then
    LINE_TYPE_ARRAY_1_OPEN=1
    ARRAY_VALUE=()
    ARRAY_INLINE=1
  elif [[ "$(perl -nle 'if (/^[[:space:]]*\[/) { print $&; exit }' <<< "${CURRENT_LINE}")" && -z "${LINE_TYPE_ARRAY_1_OPEN}" ]]; then
    LINE_TYPE_ARRAY_1_OPEN=1
    ARRAY_VALUE=()
  fi

  if [[ LINE_TYPE_ARRAY_1_OPEN -eq 0 ]]; then
    return
  fi

  CURRENT_LINE_HANDLED=1

   if [[ ARRAY_INLINE -eq 1 ]]; then
    REPLACED_LINE="$(echo "${CURRENT_LINE}" | perl -pe "s/^.*?[[:space:]]+\[//" | perl -pe "s/\][[:space:]]*$//")"
  else
    REPLACED_LINE="$(echo "${CURRENT_LINE}" | perl -pe "s/^[[:space:]]*\[//" | perl -pe "s/\][[:space:]]*$//" )"
  fi

  IFS=','; for EXPLODED_ITEM in ${REPLACED_LINE}; do
    ARRAY_VALUE+=("$(trim "${EXPLODED_ITEM}")")
  done

  if [[ "$(perl -nle 'if (/\][[:space:]]*$/) { print $&; exit }' <<< "${CURRENT_LINE}")" || "${IS_LAST_LINE}" -eq 1 ]]; then
    if (( ${#ARRAY_VALUE[@]} )); then
      local i
      for (( i = 0; i < ${#ARRAY_VALUE[*]}; ++ i )); do
        writeValueToNamespace "${ARRAY_VALUE[$i]}" "${i}"
      done
    fi

    unset LINE_TYPE_ARRAY_1_OPEN
    resetNamespace "${KEY_LEADING_SPACES}"
    reset
  fi
}

function reset() {
#  unset KEY_LEADING_SPACES
  unset KEY
  unset VALUE
}

function countLeadingSpaces() {
  awk -F'[^ ]' '{print length($1)}' <<< "${1}"
}

function removeLeadingSpaces() {
  if [ -n "${2}" ]; then
    echo "${1}" | perl -pe "s/^[[:space:]]\{${2}\}//"
  else
    echo "${1}" | perl -pe "s/^[[:space:]]*//"
  fi
}

function replaceNonAlphanumericWithUnderscore() {
  echo "${1}" | perl -lpe "s/[^a-zA-Z0-9]/_/g"
}

#function replaceSpaceWithUnderscore() {
#  echo "${1// /_}"
#}

function capitalize() {
  echo "${1^^}"
}

function trim() {
  echo "${1}" | perl -pe 's/^[[:space:]]*//' | perl -pe 's/[[:space:]]*$//'
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

function isLastLine() {
  CURRENT_LINE_NUMBER="${1}"
  NEXT_LINE_NUMBER="$((CURRENT_LINE_NUMBER+1))"
  TOTAL_LINES="$(wc -l "${PATH_TO_YAML_FILE}" | awk '{ print $1 }')"

  if [[ "${TOTAL_LINES}" == "${NEXT_LINE_NUMBER}" ]]; then
    echo 1
  else
    echo 0
  fi
}

rm -f  "${PATH_TO_ENV_FILE}"
mapfile -t LINES < "${PATH_TO_YAML_FILE}"

if (( ${#LINES[@]} )); then
  for (( i = 0; i < ${#LINES[*]}; ++ i )); do
    CURRENT_LINE="${LINES[$i]}"
    CURRENT_LEADING_SPACES="$(countLeadingSpaces "${LINES[$i]}")"
    CURRENT_LINE_HANDLED=0
#    NEXT_LINE="${LINES[$i+1]}"
#    NEXT_LEADING_SPACES="$(countLeadingSpaces "${LINES[$i+1]}")"
    IS_LAST_LINE="$(isLastLine "${i}")"

    handleLine

#    PREVIOUS_LINE="${CURRENT_LINE}"
#    PREVIOUS_LEADING_SPACES="${CURRENT_LEADING_SPACES}"
  done
fi