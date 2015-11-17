-module(ts_A_select_unexpected_token_not_allowed).

-behavior(riak_test).

-include_lib("eunit/include/eunit.hrl").

-export([confirm/0]).

confirm() ->
    Cluster = single,
    TestType = normal,
    DDL = timeseries_util:get_ddl(docs),
    Data = timeseries_util:get_valid_select_data(),
    Qry =
        "selectah * from GeoCheckin "
        "Where time > 1 and time < 10",
    Expected =
        {error, decoding_error_msg("Unexpected token 'selectah'")},
    Got = timeseries_util:confirm_select(Cluster, TestType, DDL, Data, Qry),
    ?assertEqual(Expected, Got),
    pass.

decoding_error_msg(Msg) ->
    iolist_to_binary(io_lib:format("Message decoding error: ~p", [Msg])).
