const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const publish = require('../.github/scripts/publish-beta.cjs');

function fixture(t, options = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'devcpp-prerelease-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const version = options.version || '1.1.3~beta1';
  fs.writeFileSync(path.join(root, 'VERSION'), version + '\n');
  fs.mkdirSync(path.join(root, 'dist'));
  const names = [`linux-noi-lazarus-${version}-src.tar.gz`,
    `linux-noi-lazarus-${version}-src.zip`, `dev-cpp-linux_${version}_amd64.deb`];
  for (const name of names) fs.writeFileSync(path.join(root, 'dist', name), 'verified fixture');
  const context = {ref: 'refs/heads/beta', eventName: 'push',
    sha: 'a'.repeat(40),
    repo: {owner: 'example', repo: 'devcpp'}, runId: 42, ...options.context};
  const calls = [];
  let ref = options.ref;
  let release = options.release;
  const assets = options.assets || [];
  function missing() { throw Object.assign(new Error('Not found'), {status: 404}); }
  const repos = {
    getReleaseByTag: async () => ({data: release && !release.draft ? release : missing()}),
    listReleases: async () => ({data: release ? [release] : []}),
    listReleaseAssets: async () => ({data: assets}),
    createRelease: async args => {
      calls.push(['createRelease', args]);
      release = {id: 1, ...args};
      return {data: release};
    },
    uploadReleaseAsset: async args => {
      calls.push(['upload', args]);
      assets.push({id: assets.length + 10, name: args.name, state: 'uploaded', size: args.data.length});
    },
    deleteReleaseAsset: async args => {
      calls.push(['delete', args]);
      assets.splice(assets.findIndex(asset => asset.id === args.asset_id), 1);
    },
    updateRelease: async args => {
      calls.push(['publish', args]);
      release = {...release, ...args};
      return {data: release};
    }
  };
  const github = {rest: {repos, git: {
    getRef: async () => { calls.push(['getRef']); return {data: ref || missing()}; },
    createRef: async args => {
      calls.push(['createRef', args]);
      ref = {object: {type: 'commit', sha: args.sha}};
      return {data: ref};
    }
  }}, paginate: async (method, args) => (await method(args)).data};
  return {root, names, calls, options: {github, context, core: {info() {}}, root}};
}

test('publishes exactly three assets before making the beta public; reruns preserve them', async t => {
  const f = fixture(t);
  await publish(f.options);
  assert.deepEqual(f.calls.map(call => call[0]),
    ['getRef', 'createRef', 'createRelease', 'upload', 'upload', 'upload', 'publish']);
  const creation = f.calls.find(call => call[0] === 'createRelease')[1];
  assert.equal(creation.tag_name, 'v1.1.3-beta1');
  assert.equal(creation.target_commitish, f.options.context.sha);
  assert.equal(creation.draft, true);
  assert.equal(creation.prerelease, true);
  assert.equal(creation.make_latest, 'false');
  assert.deepEqual(f.calls.filter(call => call[0] === 'upload').map(call => call[1].name),
    f.names.map(name => name.replace(/~/g, '-')));
  const publication = f.calls.at(-1)[1];
  assert.equal(publication.draft, false);
  assert.equal(publication.prerelease, true);
  assert.equal(publication.make_latest, 'false');
  f.calls.length = 0;
  await publish(f.options);
  assert.deepEqual(f.calls.map(call => call[0]), ['getRef']);
});

test('branch, event, version and missing artifacts are rejected before any GitHub mutation', async t => {
  for (const options of [{context: {ref: 'refs/heads/main'}},
    {context: {eventName: 'workflow_dispatch', payload: {}}},
    {context: {eventName: 'workflow_dispatch', payload: {inputs: {publish_beta: 'false'}}}},
    {context: {eventName: 'pull_request'}}, {version: '1.3.0-invalid'}]) {
    const f = fixture(t, options);
    await assert.rejects(publish(f.options));
    assert.equal(f.calls.length, 0);
  }
  const f = fixture(t);
  fs.unlinkSync(path.join(f.root, 'dist', f.names[2]));
  await assert.rejects(publish(f.options));
  assert.equal(f.calls.length, 0);
});

test('manual checks publish only when publish_beta is explicitly enabled', async t => {
  const f = fixture(t, {context: {eventName: 'workflow_dispatch',
    payload: {inputs: {publish_beta: 'true'}}}});
  await publish(f.options);
  assert.deepEqual(f.calls.filter(call => call[0] === 'upload').map(call => call[1].name),
    f.names.map(name => name.replace(/~/g, '-')));
  assert.equal(f.calls.at(-1)[0], 'publish');
});

test('a reused version cannot move an existing tag to another commit', async t => {
  const f = fixture(t, {ref: {object: {type: 'commit', sha: 'b'.repeat(40)}}});
  await assert.rejects(publish(f.options), /Increment VERSION/);
  assert.deepEqual(f.calls.map(call => call[0]), ['getRef']);
});

test('a stable release is never converted into a Pre-release', async t => {
  const f = fixture(t, {ref: {object: {type: 'commit', sha: 'a'.repeat(40)}},
    release: {id: 1, tag_name: 'v1.1.3-beta1', draft: false, prerelease: false}});
  await assert.rejects(publish(f.options), /stable release/);
  assert.deepEqual(f.calls.map(call => call[0]), ['getRef']);
});

test('an interrupted draft resumes uploads without replacing complete assets', async t => {
  const f = fixture(t, {ref: {object: {type: 'commit', sha: 'a'.repeat(40)}},
    release: {id: 1, tag_name: 'v1.1.3-beta1', target_commitish: 'a'.repeat(40), draft: true, prerelease: true},
    assets: [{id: 10, name: 'linux-noi-lazarus-1.1.3-beta1-src.tar.gz', state: 'uploaded', size: 16},
      {id: 11, name: 'linux-noi-lazarus-1.1.3-beta1-src.zip', state: 'starter', size: 0}]});
  await publish(f.options);
  assert.deepEqual(f.calls.map(call => call[0]), ['getRef', 'delete', 'upload', 'upload', 'publish']);
  assert.equal(f.calls[1][1].asset_id, 11);
});

// A user-requested numeric version on beta is still a Pre-release, never latest.
test('numeric beta version publishes v1.3.0 as a Pre-release', async t => {
  const f = fixture(t, {version: '1.3.0'});
  await publish(f.options);
  const release = f.calls.find(call => call[0] === 'createRelease')[1];
  assert.equal(release.tag_name, 'v1.3.0');
  assert.equal(release.prerelease, true);
  assert.equal(release.make_latest, 'false');
  assert.equal(f.calls.at(-1)[1].prerelease, true);
});
