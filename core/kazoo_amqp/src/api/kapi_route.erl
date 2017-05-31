%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2017, 2600Hz INC
%%% @doc
%%% Routing requests, responses, and wins!
%%% @end
%%% @contributors
%%%   James Aimonetti
%%%   Karl Anderson
%%%-------------------------------------------------------------------
-module(kapi_route).

-export([req/1, req_v/1
        ,resp/1, resp_v/1
        ,win/1, win_v/1
        ,bind_q/2, unbind_q/2
        ,declare_exchanges/0
        ,publish_req/1, publish_req/2
        ,publish_resp/2, publish_resp/3
        ,publish_win/2, publish_win/3
        ,get_auth_realm/1
        ,get_auth_user/1
        ,req_event_type/0
        ,is_actionable_resp/1

        ,call_id/1
        ,control_queue/1
        ,fetch_id/1
        ]).

-include_lib("amqp_util.hrl").
-include("kapi_dialplan.hrl").

-type req() :: kz_json:object().
-type resp() :: kz_json:object().

-export_type([req/0, resp/0]).

-define(KEY_CALL_ID, <<"Call-ID">>).
-define(KEY_CONTROL_QUEUE, <<"Control-Queue">>).
-define(KEY_FETCH_ID, [<<"Custom-Channel-Vars">>, <<"Fetch-ID">>]).

%% routing keys to use in the callmgr exchange
-define(KEY_ROUTE_REQ, <<"route.req">>). %% corresponds to the route_req/1 api call

-define(EVENT_CATEGORY, <<"dialplan">>).
-define(ROUTE_REQ_EVENT_NAME, <<"route_req">>).

%% Route Requests
-define(ROUTE_REQ_HEADERS, [<<"To">>, <<"From">>, <<"Request">>, ?KEY_CALL_ID
                           ]).
-define(OPTIONAL_ROUTE_REQ_HEADERS, [<<"Geo-Location">>, <<"Orig-IP">>, <<"Orig-Port">>
                                    ,<<"Max-Call-Length">>, <<"Media">>
                                    ,<<"Transcode">>, <<"Codecs">>
                                    ,<<"Custom-Channel-Vars">>, <<"Custom-SIP-Headers">>
                                    ,<<"Resource-Type">>, <<"Cost-Parameters">>
                                    ,<<"From-Network-Addr">>, <<"From-Network-Port">>
                                    ,<<"User-Agent">>
                                    ,<<"Switch-Hostname">>, <<"Switch-Nodename">>
                                    ,<<"Switch-URL">>, <<"Switch-URI">>
                                    ,<<"Ringback-Media">>, <<"Transfer-Media">>
                                    ,<<"SIP-Request-Host">>, <<"Message-ID">>
                                    ,<<"Body">>
                                    ,<<"From-Tag">>, <<"To-Tag">>
                                    ,<<"Prepend-CID-Name">>
                                    ,<<"Call-Direction">>
                                    ,<<"Custom-Routing-Headers">>
                                    ,<<"Caller-ID-Name">>
                                    ,<<"Caller-ID-Number">>
                                    ]).
-define(ROUTE_REQ_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                          ,{<<"Event-Name">>, ?ROUTE_REQ_EVENT_NAME}
                          ,{<<"Resource-Type">>, [<<"mms">>, <<"sms">>
                                                 ,<<"audio">>, <<"video">>
                                                 ,<<"chat">>, <<"metaflow">>
                                                 ]}
                          ,{<<"Media">>, [<<"process">>, <<"proxy">>, <<"bypass">>]}
                          ]).
-define(ROUTE_REQ_COST_PARAMS, [<<"Min-Increment-Cost">>, <<"Max-Incremental-Cost">>
                               ,<<"Min-Setup-Cost">>, <<"Max-Setup-Cost">>
                               ]).
-define(ROUTE_REQ_TYPES, [{<<"To">>, fun is_binary/1}
                         ,{<<"From">>, fun is_binary/1}
                         ,{<<"Request">>, fun is_binary/1}
                         ,{?KEY_CALL_ID, fun is_binary/1}
                         ,{<<"Event-Queue">>, fun is_binary/1}
                         ,{<<"Caller-ID-Name">>, fun is_binary/1}
                         ,{<<"Caller-ID-Number">>, fun is_binary/1}
                         ,{<<"Cost-Parameters">>, fun has_cost_parameters/1}
                         ,{<<"Custom-Channel-Vars">>, fun kz_json:is_json_object/1}
                         ,{<<"Custom-SIP-Headers">>, fun kz_json:is_json_object/1}
                         ]).

-spec has_cost_parameters(kz_json:object()) -> boolean().
has_cost_parameters(JObj) ->
    kz_json:is_json_object(JObj)
        andalso kz_json:all(fun({K, _V}) ->
                                    lists:member(K, ?ROUTE_REQ_COST_PARAMS)
                            end
                           ,JObj
                           ).

%% Route Responses
-define(ROUTE_RESP_ROUTE_HEADERS, [<<"Invite-Format">>]).
-define(OPTIONAL_ROUTE_RESP_ROUTE_HEADERS, [<<"Route">>, <<"To-User">>, <<"To-Realm">>, <<"To-DID">>
                                           ,<<"Proxy-Via">>, <<"Media">>, <<"Auth-User">>
                                           ,<<"Auth-Password">>, <<"Codecs">>, <<"Progress-Timeout">>
                                           ,<<"Caller-ID-Name">>, <<"Caller-ID-Number">>, <<"Caller-ID-Type">>
                                           ,<<"Rate">>, <<"Rate-Increment">>, <<"Rate-Minimum">>
                                           ,<<"Surcharge">>, <<"Rate-NoCharge-Time">>
                                           ,<<"Custom-SIP-Headers">>, <<"Custom-Channel-Vars">>
                                           ,<<"Weight-Cost">>, <<"Weight-Location">>
                                           ]).
-define(ROUTE_RESP_ROUTE_VALUES, [{<<"Media">>, [<<"process">>, <<"bypass">>, <<"auto">>]}
                                 ,{<<"Caller-ID-Type">>, [<<"from">>, <<"rpid">>, <<"pid">>]}
                                 ,?INVITE_FORMAT_TUPLE
                                 ]).
-define(ROUTE_RESP_ROUTE_TYPES, [{<<"Codecs">>, fun is_list/1}
                                ,{<<"Route">>, fun is_binary/1}
                                ,{<<"To-User">>, fun is_binary/1}
                                ,{<<"To-Realm">>, fun is_binary/1}
                                ,{<<"Custom-SIP-Headers">>, fun kz_json:is_json_object/1}
                                ,{<<"Custom-Channel-Vars">>, fun kz_json:is_json_object/1}
                                ]).

%% Route Responses
-define(ROUTE_RESP_HEADERS, [<<"Method">>]).
-define(OPTIONAL_ROUTE_RESP_HEADERS, [<<"Custom-Channel-Vars">>, <<"Routes">>
                                     ,<<"Route-Error-Code">>, <<"Route-Error-Message">>
                                     ,<<"Ringback-Media">>, <<"Transfer-Media">>
                                     ,<<"Pre-Park">>, <<"From-User">>, <<"From-Realm">>
                                     ,<<"From-URI">>
                                     ,<<"Plan-Data">>, <<"Application-Data">>
                                     ]).
-define(ROUTE_RESP_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                           ,{<<"Event-Name">>, <<"route_resp">>}
                           ,{<<"Method">>, [<<"bridge">>, <<"park">>, <<"error">>, <<"sms">>
                                           ,<<"plan">>, <<"application">>
                                           ]
                            }
                           ,{<<"Pre-Park">>, [<<"none">>, <<"ring_ready">>, <<"answer">>]}
                           ]).
-define(ROUTE_RESP_TYPES, [{<<"Route-Error-Code">>, fun is_binary/1}
                          ,{<<"Route-Error-Message">>, fun is_binary/1}
                          ,{<<"Routes">>, fun is_list/1}
                          ,{<<"Custom-Channel-Vars">>, fun kz_json:is_json_object/1}
                          ]).

%% Route Winner
-define(ROUTE_WIN_HEADERS, [?KEY_CALL_ID, ?KEY_CONTROL_QUEUE]).
-define(OPTIONAL_ROUTE_WIN_HEADERS, [<<"Custom-Channel-Vars">>, <<"Switch-Hostname">>]).
-define(ROUTE_WIN_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                          ,{<<"Event-Name">>, <<"route_win">>}
                          ]).
-define(ROUTE_WIN_TYPES, [{?KEY_CALL_ID, fun is_binary/1}
                         ,{?KEY_CONTROL_QUEUE, fun is_binary/1}
                         ,{<<"Custom-Channel-Vars">>, fun kz_json:is_json_object/1}
                         ]).

%%--------------------------------------------------------------------
%% @doc Dialplan Route Request - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec req(api_terms()) ->
                 {'ok', iolist()} |
                 {'error', string()}.
req(Prop) when is_list(Prop) ->
    case req_v(Prop) of
        'true' -> kz_api:build_message(Prop, ?ROUTE_REQ_HEADERS, ?OPTIONAL_ROUTE_REQ_HEADERS);
        'false' -> {'error', "Proplist failed validation for route_req"}
    end;
req(JObj) -> req(kz_json:to_proplist(JObj)).

-spec req_v(api_terms()) -> boolean().
req_v(Prop) when is_list(Prop) ->
    kz_api:validate(Prop, ?ROUTE_REQ_HEADERS, ?ROUTE_REQ_VALUES, ?ROUTE_REQ_TYPES);
req_v(JObj) -> req_v(kz_json:to_proplist(JObj)).

-spec req_event_type() -> {ne_binary(), ne_binary()}.
req_event_type() -> {?EVENT_CATEGORY, ?ROUTE_REQ_EVENT_NAME}.

%%--------------------------------------------------------------------
%% @doc Dialplan Route Response - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec resp(api_terms()) ->
                  {'ok', iolist()} |
                  {'error', string()}.
resp(Prop) when is_list(Prop) ->
    Prop1 = case props:get_value(<<"Method">>, Prop) of
                <<"bridge">> ->
                    Routes = [begin
                                  {'ok', RouteProp} = resp_route(Route),
                                  kz_json:from_list(RouteProp)
                              end || Route <- props:get_value(<<"Routes">>, Prop)],
                    [{<<"Routes">>, Routes} | props:delete(<<"Routes">>, Prop)];
                _ ->
                    Prop
            end,
    case resp_v(Prop1) of
        'true' -> kz_api:build_message(Prop1, ?ROUTE_RESP_HEADERS, ?OPTIONAL_ROUTE_RESP_HEADERS);
        'false' -> {'error', "Proplist failed validation for route_resp"}
    end;
resp(JObj) -> resp(kz_json:to_proplist(JObj)).

-spec resp_v(api_terms()) -> boolean().
resp_v(Prop) when is_list(Prop) ->
    Valid = kz_api:validate(Prop, ?ROUTE_RESP_HEADERS, ?ROUTE_RESP_VALUES, ?ROUTE_RESP_TYPES),
    case props:get_value(<<"Method">>, Prop) of
        <<"bridge">> when Valid->
            lists:all(fun(Route) -> resp_route_v(Route) end
                     ,props:get_value(<<"Routes">>, Prop)
                     );
        _ ->
            Valid
    end;
resp_v(JObj) -> resp_v(kz_json:to_proplist(JObj)).

-spec is_actionable_resp(api_terms()) -> boolean().
is_actionable_resp(Prop) when is_list(Prop) ->
    case props:get_value(<<"Method">>, Prop) of
        <<"bridge">> -> 'true';
        <<"park">> -> 'true';
        <<"sms">> -> 'true';
        <<"plan">> -> 'true';
        <<"application">> -> 'true';
        <<"error">> ->
            kz_term:is_true(props:get_value(<<"Defer-Response">>, Prop));
        _ -> 'false'
    end;
is_actionable_resp(JObj) ->
    is_actionable_resp(kz_json:to_proplist(JObj)).

%%--------------------------------------------------------------------
%% @doc Route within a Dialplan Route Response - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec resp_route(api_terms()) ->
                        {'ok', iolist()} |
                        {'error', string()}.
resp_route(Prop) when is_list(Prop) ->
    case resp_route_v(Prop) of
        'true' -> kz_api:build_message_specific_headers(Prop, ?ROUTE_RESP_ROUTE_HEADERS, ?OPTIONAL_ROUTE_RESP_ROUTE_HEADERS);
        'false' -> {'error', "Proplist failed validation for route_resp_route"}
    end;
resp_route(JObj) -> resp_route(kz_json:to_proplist(JObj)).

-spec resp_route_v(api_terms()) -> boolean().
resp_route_v(Prop) when is_list(Prop) ->
    kz_api:validate_message(Prop, ?ROUTE_RESP_ROUTE_HEADERS, ?ROUTE_RESP_ROUTE_VALUES, ?ROUTE_RESP_ROUTE_TYPES);
resp_route_v(JObj) -> resp_route_v(kz_json:to_proplist(JObj)).

%%--------------------------------------------------------------------
%% @doc Winning Responder Message - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec win(api_terms()) ->
                 {'ok', iolist()} |
                 {'error', string()}.
win(Prop) when is_list(Prop) ->
    case win_v(Prop) of
        'true' -> kz_api:build_message(Prop, ?ROUTE_WIN_HEADERS, ?OPTIONAL_ROUTE_WIN_HEADERS);
        'false' -> {'error', "Proplist failed validation for route_win"}
    end;
win(JObj) -> win(kz_json:to_proplist(JObj)).

-spec win_v(api_terms()) -> boolean().
win_v(Prop) when is_list(Prop) ->
    kz_api:validate(Prop, ?ROUTE_WIN_HEADERS, ?ROUTE_WIN_VALUES, ?ROUTE_WIN_TYPES);
win_v(JObj) -> win_v(kz_json:to_proplist(JObj)).

%%--------------------------------------------------------------------
%% @doc Bind AMQP Queue for routing requests
%% @end
%%--------------------------------------------------------------------
-spec bind_q(ne_binary(), kz_proplist()) -> 'ok'.
bind_q(Queue, Props) ->
    bind_q(Queue, props:get_value('restrict_to', Props), Props).

-spec bind_q(ne_binary(), list() | 'undefined', kz_proplist()) -> 'ok'.
bind_q(Queue, 'undefined', Props) ->
    Keys = get_all_routing_keys(Props),
    lists:foreach(fun(Key) -> amqp_util:bind_q_to_callmgr(Queue, Key) end, Keys);
bind_q(Queue, ['no_account' | T], Props) ->
    Keys = get_realm_routing_keys(Props),
    lists:foreach(fun(Key) -> amqp_util:bind_q_to_callmgr(Queue, Key) end, Keys),
    bind_q(Queue, T, Props);
bind_q(Queue, ['account' | T], Props) ->
    Keys = get_account_routing_keys(Props),
    lists:foreach(fun(Key) -> amqp_util:bind_q_to_callmgr(Queue, Key) end, Keys),
    bind_q(Queue, T, Props);
bind_q(Queue, [_ | T], Props) ->
    bind_q(Queue, T, Props);
bind_q(_, [], _) -> 'ok'.

-spec unbind_q(ne_binary(), kz_proplist()) -> 'ok'.
unbind_q(Queue, Props) ->
    unbind_q(Queue, props:get_value('restrict_to', Props), Props).

-spec unbind_q(ne_binary(), list() | 'undefined', kz_proplist()) -> 'ok'.
unbind_q(Queue, 'undefined', Props) ->
    Keys = get_all_routing_keys(Props),
    lists:foreach(fun(Key) -> amqp_util:unbind_q_from_callmgr(Queue, Key) end, Keys);
unbind_q(Queue, ['no_account' | T], Props) ->
    Keys = get_realm_routing_keys(Props),
    lists:foreach(fun(Key) -> amqp_util:unbind_q_from_callmgr(Queue, Key) end, Keys),
    unbind_q(Queue, T, Props);
unbind_q(Queue, ['account' | T], Props) ->
    Keys = get_account_routing_keys(Props),
    lists:foreach(fun(Key) -> amqp_util:unbind_q_from_callmgr(Queue, Key) end, Keys),
    unbind_q(Queue, T, Props);
unbind_q(Queue, [_ | T], Props) ->
    unbind_q(Queue, T, Props);
unbind_q(_, [], _) -> 'ok'.

get_all_routing_keys(Props) ->
    get_realm_routing_keys(Props) ++ get_account_routing_keys(Props).

get_realm_routing_keys(Props) ->
    Realm = props:get_value('realm', Props, <<"*">>),
    User = props:get_value('user', Props, <<"*">>),
    Types = props:get_value('types', Props, [<<"*">>]),
    lists:foldl(fun(T, L) -> [get_route_req_realm_routing(T, Realm, User) | L] end, [], Types).

get_account_routing_keys(Props) ->
    AccountId = props:get_value('account_id', Props, <<"*">>),
    Types = props:get_value('types', Props, [<<"*">>]),
    lists:foldl(fun(T, L) -> [get_route_req_account_routing(T, AccountId) | L] end, [], Types).

%%--------------------------------------------------------------------
%% @doc
%% declare the exchanges used by this API
%% @end
%%--------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    amqp_util:callmgr_exchange().

-spec get_route_req_account_routing(ne_binary(), ne_binary()) -> ne_binary().
get_route_req_account_routing(Type, AccountId) ->
    list_to_binary([?KEY_ROUTE_REQ, ".", amqp_util:encode(Type), ".", amqp_util:encode(AccountId)]).

-spec get_route_req_realm_routing(ne_binary(), ne_binary(), ne_binary()) -> ne_binary().
get_route_req_realm_routing(Type, Realm, User) ->
    list_to_binary([?KEY_ROUTE_REQ, ".", amqp_util:encode(Type), ".", amqp_util:encode(Realm), ".", amqp_util:encode(User)]).

-spec get_route_req_routing(api_terms()) -> ne_binary().
get_route_req_routing(Api) ->
    {User, Realm} = get_auth_user_realm(Api),
    Type = resource_type(Api),
    case account_id(Api) of
        'undefined' -> get_route_req_realm_routing(Type, Realm, User);
        AccountId -> get_route_req_account_routing(Type, AccountId)
    end.

-spec publish_req(api_terms()) -> 'ok'.
-spec publish_req(api_terms(), binary()) -> 'ok'.
publish_req(JObj) ->
    publish_req(JObj, ?DEFAULT_CONTENT_TYPE).
publish_req(Req, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(Req, ?ROUTE_REQ_VALUES, fun req/1),
    amqp_util:callmgr_publish(Payload, ContentType, get_route_req_routing(Req)).

-spec publish_resp(ne_binary(), api_terms()) -> 'ok'.
-spec publish_resp(ne_binary(), api_terms(), ne_binary()) -> 'ok'.
publish_resp(RespQ, JObj) ->
    publish_resp(RespQ, JObj, ?DEFAULT_CONTENT_TYPE).
publish_resp(RespQ, Resp, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(Resp, ?ROUTE_RESP_VALUES, fun resp/1),
    amqp_util:targeted_publish(RespQ, Payload, ContentType).

-spec publish_win(ne_binary(), api_terms()) -> 'ok'.
-spec publish_win(ne_binary(), api_terms(), binary()) -> 'ok'.
publish_win(RespQ, JObj) ->
    publish_win(RespQ, JObj, ?DEFAULT_CONTENT_TYPE).
publish_win(RespQ, Win, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(Win, ?ROUTE_WIN_VALUES, fun win/1),
    amqp_util:targeted_publish(RespQ, Payload, ContentType).

%%-----------------------------------------------------------------------------
%% @private
%% @doc
%% extract the auth realm from the API request, using the requests to domain
%% when provided with an IP
%% @end
%%-----------------------------------------------------------------------------
-spec get_auth_realm(api_terms()) -> ne_binary().
get_auth_realm(ApiProp) when is_list(ApiProp) ->
    [_ReqUser, ReqDomain] = binary:split(props:get_value(<<"From">>, ApiProp), <<"@">>),
    ReqDomain;
get_auth_realm(ApiJObj) ->
    [_ReqUser, ReqDomain] = binary:split(kz_json:get_value(<<"From">>, ApiJObj), <<"@">>),
    ReqDomain.

-spec get_auth_user(api_terms()) -> ne_binary().
get_auth_user(ApiProp) when is_list(ApiProp) ->
    [ReqUser, _ReqDomain] = binary:split(props:get_value(<<"From">>, ApiProp), <<"@">>),
    ReqUser;
get_auth_user(ApiJObj) ->
    [ReqUser, _ReqDomain] = binary:split(kz_json:get_value(<<"From">>, ApiJObj), <<"@">>),
    ReqUser.

-spec get_auth_user_realm(api_terms()) -> {ne_binary(), ne_binary()}.
get_auth_user_realm(ApiProp) when is_list(ApiProp) ->
    [ReqUser, ReqDomain] = binary:split(props:get_value(<<"From">>, ApiProp), <<"@">>),
    {ReqUser, ReqDomain};
get_auth_user_realm(ApiJObj) ->
    [ReqUser, ReqDomain] = binary:split(kz_json:get_value(<<"From">>, ApiJObj), <<"@">>),
    {ReqUser, ReqDomain}.

-spec account_id(api_terms()) -> api_binary().
account_id(API) when is_list(API) ->
    account_id(kz_json:from_list(API));
account_id(API) ->
    kz_json:get_first_defined([<<"Account-ID">>
                              ,[<<"Custom-Channel-Vars">>, <<"Account-ID">>]
                              ], API).

-spec resource_type(api_terms()) -> ne_binary().
resource_type(ApiProp) when is_list(ApiProp) ->
    props:get_value(<<"Resource-Type">>, ApiProp);
resource_type(ApiJObj) ->
    kz_json:get_value(<<"Resource-Type">>, ApiJObj).

-spec call_id(kz_json:object()) -> api_binary().
call_id(JObj) ->
    kz_json:get_value(?KEY_CALL_ID, JObj).

-spec fetch_id(kz_json:object()) -> api_binary().
fetch_id(JObj) ->
    kz_json:get_value(?KEY_FETCH_ID, JObj).

-spec control_queue(kz_json:object()) -> api_binary().
control_queue(JObj) ->
    kz_json:get_value(?KEY_CONTROL_QUEUE, JObj).
