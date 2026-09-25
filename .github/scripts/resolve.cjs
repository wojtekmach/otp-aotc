const fs = require('node:fs');

// Resolve moving names once. Every matrix job builds the same immutable inputs.
module.exports = async function resolve({github, context, core,
  config = JSON.parse(fs.readFileSync('.github/build.json', 'utf8')),
  requestedRef = process.env.REQUESTED_OTP_REF}) {
  const otp = {owner: 'erlang', repo: 'otp'};
  let ref = requestedRef || config.otp_commit;
  if (context.eventName === 'schedule') {
    ref = (await github.rest.repos.getLatestRelease(otp)).data.tag_name;
  }
  const sha = (await github.rest.repos.getCommit({...otp, ref})).data.sha;
  for (const commit of [sha, config.elixir_commit, context.sha]) {
    if (!/^[0-9a-f]{40}$/.test(commit)) throw new Error(`Invalid commit: ${commit}`);
  }
  if (!/^\d+\.\d+\.\d+$/.test(config.hex_version)) throw new Error('Invalid Hex version');
  const tag = `otp-${sha.slice(0, 12)}-aot-${context.sha.slice(0, 12)}`;
  let build = true;
  // Drafts also count: don't rebuild the same successful candidate every day.
  // The get-by-tag endpoint only promises published releases; list explicitly.
  if (context.eventName !== 'pull_request') {
    const releases = await github.paginate(github.rest.repos.listReleases, {...context.repo, per_page: 100});
    build = !releases.some(release => release.tag_name === tag);
  }
  core.setOutput('otp_sha', sha);
  core.setOutput('elixir_sha', config.elixir_commit);
  core.setOutput('hex_version', config.hex_version);
  core.setOutput('release_tag', tag);
  core.setOutput('build', String(build));
  core.notice(`OTP ${ref} resolved to ${sha}; ${build ? 'building' : 'already released'} ${tag}`);
};
