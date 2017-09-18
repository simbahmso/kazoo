#!/bin/bash -e

pushd "$(dirname "$0")" >/dev/null

ROOT="$(pwd -P)"/..

replace() {
    local M0=$1
    local F0=$2
    local M1=$3
    local F1=$4
    for FILE in $(grep -Irl $M0:$F0 "$ROOT"/{core,applications}); do
        sed -i "s%$M0:$F0%$M1:$F1%g" "$FILE"
    done
}

replace_call() {
    FROM="$1"
    TO="$2"
    OLD_FUN="$3"
    NEW_FUN="${3%$4}"
    FILE="$5"

    #echo "s/$FROM:$OLD_FUN/$TO:$NEW_FUN/g"
    sed -i "s%$FROM:$OLD_FUN%$TO:$NEW_FUN%g" "$FILE"
}

search_and_replace() {
    declare -a FUNS=("${!1}")
    FROM="$2"
    TO="$3"
    SUFFIX="$4"

    for FUN in "${FUNS[@]}"; do
        for FILE in $(grep -Irl $FROM:$FUN "$ROOT"/{core,applications}); do
            replace_call $FROM $TO "$FUN" "$SUFFIX" "$FILE"
        done
    done
}

search_and_replace_exact() {
    declare -a FUNS=("${!1}")
    FROM=$2
    TO=$3
    TOFUN=$4

    for FUN in "${FUNS[@]}"; do
        for FILE in `grep -rl "$FROM:$FUN" $ROOT/{core,applications}`; do
            replace $FROM $TO "$FUN" "$TOFUN" $FILE
        done
    done
}

replace_call_prefix() {
    FROM="$1"
    TO="$2"
    OLD_FUN="$3"
    NEW_FUN="${3#$4}"
    FILE="$5"

    #echo "s/$FROM:$OLD_FUN/$TO:$NEW_FUN/g"
    sed -i "s%$FROM:$OLD_FUN%$TO:$NEW_FUN%g" "$FILE"
}

search_and_replace_prefix() {
    declare -a FUNS=("${!1}")
    FROM="$2"
    TO="$3"
    PREFIX="$4"

    for FUN in "${FUNS[@]}"; do
        for FILE in $(grep -Irl $FROM:$FUN "$ROOT"/{core,applications}); do
            replace_call_prefix $FROM $TO "$FUN" "$PREFIX" "$FILE"
        done
    done
}

replace_call_with_prefix() {
    FROM="$1"
    TO="$2"
    OLD_FUN="$3"
    NEW_FUN="$4$3"
    FILE="$5"

    #echo "s/$FROM:$OLD_FUN/$TO:$NEW_FUN/g"
    sed -i "s%$FROM:$OLD_FUN%$TO:$NEW_FUN%g" "$FILE"
}

search_and_replace_with_prefix() {
    declare -a FUNS=("${!1}")
    FROM="$2"
    TO="$3"
    PREFIX="$4"

    for FUN in "${FUNS[@]}"; do
        for FILE in $(grep -Irl $FROM:$FUN "$ROOT"/{core,applications}); do
            replace_call_with_prefix $FROM $TO "$FUN" "$PREFIX" "$FILE"
        done
    done
}

# Functions moved from kz_util into more appropriately-named modules
# Run this to convert references from kz_util:* to the new module names

kz_util_to_term() {
    local fs=(shuffle_list
              to_integer
              to_float
              to_number
              to_hex
              to_hex_binary
              to_hex_char
              to_list
              to_binary
              to_atom
              to_boolean
              to_date
              to_datetime
              to_lower_binary
              to_lower_string
              to_upper_binary
              to_upper_string
              to_upper_char
              to_lower_char
              error_to_binary

              is_true
              is_false
              is_boolean
              is_ne_binary
              is_empty
              is_not_empty
              is_proplist
              identity
              always_true
              always_false
              a1hash
              floor
              ceiling
             )
    search_and_replace fs[@] kz_util kz_term ''
}

kz_util_to_binary() {
    local fs=(rand_hex_binary
              hexencode_binary
              from_hex_binary
              ucfirst_binary
              lcfirst_binary
              strip_binary
              strip_left_binary
              strip_right_binary
              suffix_binary
              truncate_binary
              truncate_left_binary
              truncate_right_binary
              from_hex_string
              clean_binary
              remove_white_spaces
              binary_md5
              pad_binary
              pad_binary_left
              join_binary
              binary_reverse
             )
    local special=(binary_md5 binary_reverse)
    search_and_replace             fs[@] kz_util   kz_binary _binary
    search_and_replace        special[@] kz_util   kz_binary binary_
    search_and_replace_prefix special[@] kz_binary kz_binary binary_
}

kz_util_to_time() {
    local fs=(current_tstamp
              current_unix_tstamp
              decr_timeout
              elapsed_ms
              elapsed_ms
              elapsed_s
              elapsed_s
              elapsed_us
              elapsed_us
              format_date
              format_datetime
              format_time
              gregorian_seconds_to_unix_seconds
              iso8601
              microseconds_to_seconds
              milliseconds_to_seconds
              month
              now
              now_ms
              now_s
              now_us
              pad_month
              pretty_print_datetime
              pretty_print_elapsed_s
              rfc1036
              unitfy_seconds
              unix_seconds_to_gregorian_seconds
              unix_timestamp_to_gregorian_seconds
              weekday
             )
    search_and_replace fs[@] kz_util kz_time ''
}

kz_time_to_date() {
    local fs=(iso8601_date)
    local fs2=(pad_date
               pad_month
             )
    search_and_replace_exact fs[@] "kz_time" "kz_date" "to_iso8601_extended"
    search_and_replace fs2[@] "kz_time" "kz_date" ""
}

kz_json_to_kz_doc() {
    local fs=(get_public_keys
              public_fields
              private_fields
              is_private_key
             )
    search_and_replace fs[@] kz_json kz_doc ''
}

kz_json_to_kz_http() {
    local fs=(to_querystring)
    search_and_replace_with_prefix fs[@] kz_json kz_http_util json_
}

props_to_kz_http() {
    local fs=(to_querystring)
    search_and_replace_with_prefix fs[@] props kz_http_util props_
}

kapps_speech_to_kazoo_speech() {
    local fs=(create)

    local asrs=(asr_freeform
                asr_commands
               )

    search_and_replace fs[@] kapps_speech kazoo_tts ''
    search_and_replace_prefix asrs[@] kapps_speech kazoo_asr asr_
}

kz_media_recording_to_kzc_recording() {
    FROM=kz_media_recording
    TO=kzc_recording
    for FILE in $(grep -Irl $FROM: "$ROOT"/{core,applications}); do
            replace_call $FROM $TO '' '' "$FILE"
    done
}

kz_includes() {
    INCLUDES=(kz_databases.hrl
              kz_log.hrl
              kz_types.hrl
             )
    FROM=kazoo/include
    TO=kazoo_stdlib/include

    for FILE in $(grep -Irl $FROM/ "$ROOT"/{core,applications}); do
        for INCLUDE in "${INCLUDES[@]}"; do
            sed -i "s%$FROM/$INCLUDE%$TO/$INCLUDE%g" "$FILE"
        done
    done
}

dedupe() {
    replace crossbar_util get_account_doc kz_account fetch

    replace       kz_util get_account_realm kz_account fetch_realm
    replace crossbar_util get_account_realm kz_account fetch_realm

    replace  kapps_util get_account_name kz_account fetch_name
    replace kz_services account_name     kz_account fetch_name

    replace kapps_util get_event_type kz_util get_event_type
}

kapps_util() {
    replace kapps_util get_all_account_mods kazoo_modbs list_all
    replace kapps_util get_account_mods kazoo_modbs list_account
    replace kapps_util update_views kz_datamgr db_view_update
    replace kapps_util get_all_accounts kz_util get_all_accounts
    replace kapps_util get_all_accounts_and_mods kz_util get_all_accounts_and_mods
    replace kapps_util is_account_db kz_util is_account_db
    replace kapps_util is_account_mod kz_util is_account_mod
    replace kapps_util amqp_pool_send kz_amqp_worker cast
    replace kapps_util amqp_pool_request kz_amqp_worker call
    replace kapps_util amqp_pool_request_custom kz_amqp_worker call_custom
    replace kapps_util amqp_pool_collect kz_amqp_worker call_collect
    replace kapps_util find_oldest_doc kz_docs oldest
    replace kapps_util get_master_account_id kz_config_accounts master_account_id
    replace kapps_util get_master_account_db kz_config_accounts master_account_db
    replace kapps_util is_master_account kz_config_accounts is_master_account

    replace kz_account default_timezone kz_config_accounts default_timezone

    replace kz_account "" kzd_account ""

    replace kz_util set_superduper_admin kzd_account update_superduper_admin
    replace kz_util set_allow_number_additions kzd_account update_allow_number_additions
    replace kz_util format_account_id kzd_account format_account_id
    replace kz_util format_account_mod_id kzd_account format_account_mod_id
    replace kz_util format_account_db kzd_account format_account_db
    replace kz_util format_account_modb kzd_account format_account_modb

    replace kz_util normalize_account_name kzd_account normalize_name
    replace kz_util account_update kzd_account account_update

    replace kz_util get_all_accounts kzd_account get_all_accounts
    replace kz_util get_all_accounts_and_mods kzd_account get_all_accounts_and_mods
    replace kz_util is_account_db kzd_account is_account_db
    replace kz_util is_account_mod kzd_account is_account_mod
    replace kz_util is_in_account_hierarchy kzd_account is_in_account_hierarchy
    replace kz_util is_account_enabled kzd_account is_account_enabled
    replace kz_util is_account_expired kzd_account is_account_expired

    replace kz_util maybe_disable_account kzd_account maybe_disable_account
    replace kz_util disable_account kzd_account disable_account
    replace kz_util enable_account kzd_account enable_account
    replace kz_util is_system_admin kzd_account is_system_admin
}

echo "ensuring kz_term is used"
kz_util_to_term
echo "ensuring kz_binary is used"
kz_util_to_binary
echo "ensuring kz_time is used"
kz_util_to_time
echo "ensuring kz_time -> kz_date migration is performed"
kz_time_to_date
echo "ensuring kz_json:public/private are moved to kz_doc"
kz_json_to_kz_doc
echo "ensuring kz_json:to_querystring is moved to kz_http_util"
kz_json_to_kz_http
echo "ensuring props:to_querystring is moved to kz_http_util"
props_to_kz_http
echo "ensuring kapps_speech to kazoo_speech"
kapps_speech_to_kazoo_speech
echo "ensuring kz_media_recording to kzc_recording"
kz_media_recording_to_kzc_recording
echo "ensuring includes from kazoo are moved to kazoo_stdlib"
kz_includes
echo "ensuring utility calls are not duplicated all over the place"
dedupe
echo "breaking out kapps_util functions"
kapps_util

popd >/dev/null
