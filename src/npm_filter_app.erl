%%%-------------------------------------------------------------------
%%% @doc npm package search agent.
%%%
%%% Searches the npm registry for JavaScript/TypeScript packages and
%%% returns embryos with name, description, version, author, and links.
%%%
%%% API: https://registry.npmjs.org/-/v1/search?text={query}&size=10
%%%
%%% Handler contract: handle/2 (Body, Memory) -> {RawList, Memory}.
%%% @end
%%%-------------------------------------------------------------------
-module(npm_filter_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([handle/2, base_capabilities/0]).

-define(SEARCH_URL, "https://registry.npmjs.org/-/v1/search?size=10&text=").

%%====================================================================
%% Capability cascade
%%====================================================================

-spec base_capabilities() -> [binary()].
base_capabilities() ->
    em_filter:base_capabilities() ++ [<<"npm">>, <<"javascript">>,
                                      <<"typescript">>, <<"nodejs">>,
                                      <<"packages">>].

%%====================================================================
%% Application behaviour
%%====================================================================

start(_Type, _Args) ->
    em_filter:start_agent(npm_filter, ?MODULE, #{
        capabilities => base_capabilities()
    }),
    {ok, self()}.

stop(_State) ->
    em_filter:stop_agent(npm_filter).

%%====================================================================
%% Agent handler
%%====================================================================

handle(Body, Memory) when is_binary(Body) ->
    {generate_embryo_list(Body), Memory};
handle(_Body, Memory) ->
    {[], Memory}.

%%====================================================================
%% Search and processing
%%====================================================================

generate_embryo_list(JsonBinary) ->
    {Query, Timeout} = extract_params(JsonBinary),
    fetch_results(Query, Timeout).

extract_params(JsonBinary) ->
    try json:decode(JsonBinary) of
        Map when is_map(Map) ->
            Query = binary_to_list(maps:get(<<"value">>, Map,
                        maps:get(<<"query">>, Map, <<"">>))),
            Timeout = to_timeout(maps:get(<<"timeout">>, Map, undefined)),
            {Query, Timeout};
        _ ->
            {binary_to_list(JsonBinary), 10}
    catch
        _:_ -> {binary_to_list(JsonBinary), 10}
    end.

fetch_results("", _) -> [];
fetch_results(Query, Timeout) ->
    Url = lists:flatten(io_lib:format("~s~s", [?SEARCH_URL, uri_string:quote(Query)])),
    case httpc:request(get, {Url, []},
                       [{timeout, Timeout * 1000},
                        {ssl, [{verify, verify_none}]}],
                       [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} -> parse_results(Body);
        _                            -> []
    end.

parse_results(JsonBin) ->
    try json:decode(JsonBin) of
        #{<<"objects">> := Objects} when is_list(Objects) ->
            lists:filtermap(fun build_embryo/1, Objects);
        _ -> []
    catch
        _:_ -> []
    end.

build_embryo(#{<<"package">> := Pkg}) ->
    Name    = maps:get(<<"name">>,        Pkg, <<"">>),
    Desc    = maps:get(<<"description">>, Pkg, <<"">>),
    Version = maps:get(<<"version">>,     Pkg, <<"">>),
    Links   = maps:get(<<"links">>,       Pkg, #{}),
    Npm     = maps:get(<<"npm">>,         Links, <<"">>),
    Url     = case Npm of
        <<>> -> iolist_to_binary(["https://www.npmjs.com/package/", Name]);
        _    -> Npm
    end,
    Author  = case maps:get(<<"publisher">>, Pkg, undefined) of
        undefined -> <<>>;
        P         -> maps:get(<<"username">>, P, <<>>)
    end,
    Resume  = format_resume(Desc, Version, Author),
    {true, #{<<"properties">> => #{
        <<"url">>     => Url,
        <<"title">>   => Name,
        <<"resume">>  => Resume,
        <<"version">> => Version,
        <<"source">>  => <<"npmjs.com">>
    }}};
build_embryo(_) -> false.

format_resume(Desc, Version, Author) ->
    D = bin(Desc),
    V = case Version of <<>> -> ""; _ -> " v" ++ binary_to_list(Version) end,
    A = case Author of <<>> -> ""; _ -> " — " ++ binary_to_list(Author) end,
    list_to_binary(D ++ V ++ A).

%%====================================================================
%% Helpers
%%====================================================================

bin(B) when is_binary(B) -> binary_to_list(B);
bin(_)                   -> "".

to_timeout(undefined)            -> 10;
to_timeout(T) when is_integer(T) -> T;
to_timeout(T) when is_binary(T)  ->
    try binary_to_integer(T) catch _:_ -> 10 end;
to_timeout(_) -> 10.
