set -e
OTP=${OTP:-$PWD/otp}
WORK=${WORK:-$PWD/work}
mkdir -p $WORK
TIMEFORMAT=%R
export PATH=$OTP/bin:$PATH
rm -rf $WORK/rel && mkdir -p $WORK/rel/lib/hello-1.0/ebin $WORK/rel/releases/1.0 && cd $WORK/rel
cat > hello_app.erl <<'ERL'
-module(hello_app).
-behaviour(application).
-export([start/2, stop/1]).
start(_, _) -> io:format("hello world~n"), {ok, spawn(fun() -> receive stop -> ok end end)}.
stop(_) -> ok.
ERL
erlc -o lib/hello-1.0/ebin hello_app.erl
cat > lib/hello-1.0/ebin/hello.app <<'APP'
{application, hello, [{description, "hello"}, {vsn, "1.0"}, {registered, []}, {modules, [hello_app]}, {applications, [kernel, stdlib]}, {mod, {hello_app, []}}]}.
APP
erl -noshell -eval '
  Copy = fun(App) ->
    application:load(App), {ok, Vsn} = application:get_key(App, vsn),
    Dst = "lib/" ++ atom_to_list(App) ++ "-" ++ Vsn ++ "/ebin", ok = filelib:ensure_path(Dst),
    Src = code:lib_dir(App) ++ "/ebin",
    {ok, Fs} = file:list_dir(Src),
    [{ok, _} = file:copy(filename:join(Src, F), filename:join(Dst, F)) || F <- Fs],
    {App, Vsn, Dst}
  end,
  Apps = [Copy(kernel), Copy(stdlib)],
  Rel = {release, {"hello", "1.0"}, {erts, erlang:system_info(version)}, [{A, V} || {A, V, _} <- Apps] ++ [{hello, "1.0"}]},
  ok = file:write_file("releases/1.0/hello.rel", io_lib:format("~p.~n", [Rel])),
  ok = systools:make_script("releases/1.0/hello", [{path, [D || {_, _, D} <- Apps] ++ ["lib/hello-1.0/ebin"]}, {outdir, "releases/1.0"}, {script_name, "start"}, no_warn_sasl]),
  file:write_file("releases/start_erl.data", erlang:system_info(version) ++ " 1.0\n"),
  halt().'
ls lib
erl -noshell -eval 'io:format("~p~n", [erlang:system_info(emu_flavor)]), halt().'
erlaotc -o $WORK/hello $WORK/rel -noshell -s init stop
ls -la $WORK/hello
unzip -l $WORK/hello | grep -c 'jitc/' || true
$WORK/hello
for i in 1 2 3 4 5; do { time $WORK/hello >/dev/null; } 2>&1; done
echo "--- with distribution:"
erlaotc -o $WORK/hello_dist $WORK/rel -noshell -sname n1 -eval 'io:format("~p~n", [node()]), halt().'
$WORK/hello_dist
echo "--- plain erl for comparison:"
for i in 1 2 3; do { time erl -noshell -s init stop; } 2>&1; done
