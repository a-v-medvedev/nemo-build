if [ "$#" -lt 2 ]; then
  echo >&2 'Usage: compiler-feedback.sh /PATH/TO/PREPROCESSED/FILES/AND/COMPILER/LOGS NAME_OF_MODULE_FILE'
  exit 1
fi

SRC_PATH=$1
TARGET_FILE=$2

cp template-feedback.html $TARGET_FILE.html

INPUT_CODE=$(< ${SRC_PATH}'/'${TARGET_FILE}'.f90')
COMPILER_LOG=$(< ${SRC_PATH}'/'${TARGET_FILE}'.log')

INPUT_CODE_ESCAPED=$(echo "$INPUT_CODE" | sed 's/&/\\&/g')
COMPILER_LOG_ESCAPED=$(echo "$COMPILER_LOG" | sed 's/&/\\&/g')

awk -v r1="$INPUT_CODE_ESCAPED" -v r2="$COMPILER_LOG_ESCAPED" '{gsub(/{{inputCode}}/, r1); gsub(/{{compilerLog}}/, r2)}1' template-feedback.html > $TARGET_FILE.html

