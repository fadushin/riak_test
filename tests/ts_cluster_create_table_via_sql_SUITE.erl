%% -------------------------------------------------------------------
%%
%% Copyright (c) 2016 Basho Technologies, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(ts_cluster_create_table_via_sql_SUITE).
-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

suite() ->
    [{timetrap,{minutes, 10}}].

-define(CUSTOM_NVAL, 4).
-define(CUSTOM_MVAL, <<"bo o''oo">>).

init_per_suite(Config) ->
    Cluster = ts_util:build_cluster(multiple),
    [{cluster, Cluster} | Config].

end_per_suite(_Config) ->
    ok.

all() ->
    [create_test,
     re_create_fail_test,
     describe_test,
     get_put_data_test,
     create_fail_because_bad_properties_test,
     get_set_property_test].


create_fail_because_bad_properties_test(Ctx) ->
    C = client_pid(Ctx),
    BadDDL =
        io_lib:format(
          "~s WITH (m_val = ~s)",
          [ddl_common(), "plain_id"]),
    Got = riakc_ts:query(C, BadDDL),
    ?assertMatch({error, {1020, _}}, Got),
    pass.

create_test(Ctx) ->
    C = client_pid(Ctx),
    GoodDDL =
        io_lib:format(
          "~s WITH (n_val=~b, m_val = '~s')",
          [ddl_common(), ?CUSTOM_NVAL, ?CUSTOM_MVAL]),
    Got1 = riakc_ts:query(C, GoodDDL),
    ?assertEqual({[],[]}, Got1),
    pass.

re_create_fail_test(Ctx) ->
    C = client_pid(Ctx),
    Got = riakc_ts:query(C, ddl_common()),
    ?assertMatch({error, {1014, _}}, Got),
    pass.

describe_test(Ctx) ->
    C = client_pid(Ctx),
    Qry = io_lib:format("DESCRIBE ~s", [ts_util:get_default_bucket()]),
    Got = ts_util:single_query(C, Qry),
    ?assertEqual(table_described(), Got),
    pass.

get_put_data_test(Ctx) ->
    C = client_pid(Ctx),
    Data = [[<<"a">>, <<"b">>, 10101010, <<"not bad">>, 42.24]],
    Key = [<<"a">>, <<"b">>, 10101010],
    ?assertMatch(ok, riakc_ts:put(C, ts_util:get_default_bucket(), Data)),
    ?assertMatch({ok, {_, Data}}, riakc_ts:get(C, ts_util:get_default_bucket(), Key, [])),
    pass.

get_set_property_test(Ctx) ->
    [Node1, Node2 | _] = ?config(cluster, Ctx),
    ExpectedPL = unenquote_varchars(
                   lists:usort(
                     custom_bucket_properties())),
    GetBucketPropsF =
        fun(Node) ->
                ActualProps =
                    lists:usort(
                      rpc:call(
                        Node, riak_core_claimant, get_bucket_type,
                        [list_to_binary(ts_util:get_default_bucket()), undefined, false])),
                [PV || {P, _} = PV <- ActualProps, lists:keymember(P, 1, ExpectedPL)]
        end,
    ?assertEqual(ExpectedPL, GetBucketPropsF(Node1)),
    ?assertEqual(ExpectedPL, GetBucketPropsF(Node2)),
    pass.


client_pid(Ctx) ->
    Nodes = ?config(cluster, Ctx),
    rt:pbc(hd(Nodes)).

custom_bucket_properties() ->
    [{n_val, ?CUSTOM_NVAL}, {m_val, ?CUSTOM_MVAL}].

ddl_common() ->
    ts_util:get_ddl(small).

table_described() ->
    {[<<"Column">>,<<"Type">>,<<"Is Null">>,<<"Primary Key">>, <<"Local Key">>],
     [{<<"myfamily">>,   <<"varchar">>,   false,  1,  1},
      {<<"myseries">>,   <<"varchar">>,   false,  2,  2},
      {<<"time">>,       <<"timestamp">>, false,  3,  3},
      {<<"weather">>,    <<"varchar">>,   false, [], []},
      {<<"temperature">>,<<"double">>,    true,  [], []}]}.

unenquote_varchars(PP) ->
    lists:map(
      fun({P, V}) when is_binary(V) ->
              {P, binary:replace(V, <<"''">>, <<"'">>)};
         (PV) -> PV
      end,
      PP).
