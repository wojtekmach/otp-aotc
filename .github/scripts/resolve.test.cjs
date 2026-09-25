const test = require('node:test');
const assert = require('node:assert/strict');
const resolve = require('./resolve.cjs');

function fixture(eventName = 'push') {
  const outputs = {};
  const calls = [];
  return {
    outputs, calls,
    config: {otp_commit: 'a'.repeat(40), elixir_commit: 'b'.repeat(40), hex_version: '2.3.2'},
    context: {eventName, sha: 'c'.repeat(40), repo: {owner: 'owner', repo: 'elixiraotc'}},
    core: {setOutput: (key, value) => { outputs[key] = value; }, notice() {}},
    github: {paginate: async () => [], rest: {repos: {
      getLatestRelease: async () => ({data: {tag_name: 'OTP-29.1'}}),
      getCommit: async ({ref}) => { calls.push(ref); return {data: {sha: 'a'.repeat(40)}}; },
      listReleases() {}
    }}}
  };
}

test('push builds the reviewed pin and publishes immutable identities', async () => {
  const f = fixture();
  await resolve(f);
  assert.deepEqual(f.calls, [f.config.otp_commit]);
  assert.equal(f.outputs.build, 'true');
  assert.equal(f.outputs.release_tag, 'otp-aaaaaaaaaaaa-aot-cccccccccccc');
});

test('schedule resolves the newest stable OTP release', async () => {
  const f = fixture('schedule');
  await resolve(f);
  assert.deepEqual(f.calls, ['OTP-29.1']);
});

test('manual ref is resolved through GitHub, never interpolated into a shell', async () => {
  const f = fixture('workflow_dispatch');
  f.requestedRef = 'OTP-29.0.3';
  await resolve(f);
  assert.deepEqual(f.calls, ['OTP-29.0.3']);
});

test('an existing release skips another expensive build', async () => {
  const f = fixture('schedule');
  f.github.paginate = async () => [{tag_name: 'otp-aaaaaaaaaaaa-aot-cccccccccccc', draft: true}];
  await resolve(f);
  assert.equal(f.outputs.build, 'false');
});

test('API failures do not masquerade as a missing release', async () => {
  const f = fixture();
  f.github.paginate = async () => { throw new Error('rate limited'); };
  await assert.rejects(resolve(f), /rate limited/);
});

test('invalid commits fail before any build inputs are emitted', async () => {
  const f = fixture();
  f.config.elixir_commit = 'main';
  await assert.rejects(resolve(f), /Invalid commit/);
  assert.deepEqual(f.outputs, {});
});

test('PRs do not query or skip releases', async () => {
  const f = fixture('pull_request');
  f.github.paginate = async () => { throw new Error('must not be called'); };
  await resolve(f);
  assert.equal(f.outputs.build, 'true');
});
