-ifndef(STEPSWITCH_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_number_manager/include/knm_phone_number.hrl").

-define(ROUTES_DB, ?KZ_OFFNET_DB).
-define(RESOURCES_DB, ?KZ_OFFNET_DB).
-define(LOCAL_RESOURCES_VIEW, <<"resources/crossbar_listing">>).

-define(LIST_ROUTES_BY_NUMBER, <<"routes/listing_by_number">>).
-define(LIST_ROUTE_DUPS, <<"routes/listing_by_assignment">>).
-define(LIST_ROUTE_ACCOUNTS, <<"routes/listing_by_account">>).
-define(LIST_RESOURCES_BY_ID, <<"resources/listing_by_id">>).

-define(APP_NAME, <<"stepswitch">>).
-define(APP_VERSION, <<"4.0.0">>).

-define(CONFIG_CAT, ?APP_NAME).

-define(CACHE_NAME, 'stepswitch_cache').
-define(STEPSWITCH_CNAM_POOL, 'stepswitch_cnam_pool').

-define(CCV(Key), [<<"Custom-Channel-Vars">>, Key]).

-define(DEFAULT_AMQP_EXCHANGE_OPTIONS
       ,kz_json:from_list([{<<"passive">>, 'true'}])
       ).

-define(RULES_HONOR_DIVERSION
       ,kapps_config:get_is_true(?CONFIG_CAT, <<"cid_rules_honor_diversions">>, 'false')
       ).

-define(RESOURCE_TYPES_HANDLED, [<<"audio">>, <<"video">>, <<"sms">>]).

-define(DEFAULT_EMERGENCY_CID_NUMBER,
        kapps_config:get_ne_binary(?CONFIG_CAT, <<"default_emergency_cid_number">>)
       ).

-define(SHOULD_FORMAT_FROM_URI
       ,kapps_config:get_is_true(?CONFIG_CAT, <<"format_from_uri">>, false)).

-ifdef(TEST).
-define(ACCOUNT_ID, <<"e6ed490b996152f639c4118f8c21d4bb">>).
-define(ACCOUNT_DB, <<"account%2Fe6%2Fed%2F490b996152f639c4118f8c21d4bb">>).
-endif.

-define(STEPSWITCH_HRL, 'true').
-endif.
