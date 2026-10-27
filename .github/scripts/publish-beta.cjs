const fs = require('node:fs');
const path = require('node:path');

// Called only after this run's ordinary-user regressions and installation test
// succeed. Downloaded artifacts belong to the same workflow run and commit.
module.exports = async function publishBeta({github, context, core, root = process.cwd()}) {
  if (context.ref !== 'refs/heads/beta' || !['push', 'workflow_dispatch'].includes(context.eventName)) {
    throw new Error('Pre-releases may only be published from the beta branch.');
  }
  const version = fs.readFileSync(path.join(root, 'VERSION'), 'utf8').trim();
  if (!/^\d+\.\d+\.\d+~beta[1-9]\d*$/.test(version)) {
    throw new Error('A beta requires a VERSION such as 1.1.3~beta1.');
  }
  const tag = `v${version.replace('~', '-')}`;
  const names = [
    `linux-noi-lazarus-${version}-src.tar.gz`,
    `linux-noi-lazarus-${version}-src.zip`,
    `devcpp-noi_${version}_amd64.deb`
  ];
  // Read every asset before creating a public tag or a draft release.
  // GitHub rewrites '~' in uploaded asset names. Choose a stable public name
  // explicitly, retaining the Debian version inside each package/archive.
  const files = names.map(name => ({name: name.replace(/~/g, '-'),
    data: fs.readFileSync(path.join(root, 'dist', name))}));
  if (files.some(file => file.data.length === 0)) throw new Error('A required beta asset is empty.');
  const {owner, repo} = context.repo;
  let ref;
  try {
    ({data: ref} = await github.rest.git.getRef({owner, repo, ref: `tags/${tag}`}));
  } catch (error) {
    if (error.status !== 404) throw error;
    ({data: ref} = await github.rest.git.createRef({owner, repo, ref: `refs/tags/${tag}`, sha: context.sha}));
  }
  if (ref.object.type !== 'commit' || ref.object.sha !== context.sha) {
    throw new Error(`${tag} already identifies another commit. Increment VERSION; existing tags are immutable.`);
  }

  let release;
  try {
    ({data: release} = await github.rest.repos.getReleaseByTag({owner, repo, tag}));
  } catch (error) {
    if (error.status !== 404) throw error;
    // The by-tag endpoint cannot find drafts. Recover a partial upload by ID.
    const releases = await github.paginate(github.rest.repos.listReleases, {owner, repo, per_page: 100});
    release = releases.find(item => item.tag_name === tag);
  }
  if (release && !release.prerelease) throw new Error('Refusing to alter a stable release.');
  if (release && release.draft && release.target_commitish !== context.sha) {
    throw new Error('The existing draft identifies another commit. Increment VERSION.');
  }
  if (!release) {
    ({data: release} = await github.rest.repos.createRelease({
      owner, repo, tag_name: tag, target_commitish: context.sha,
      name: `Dev-Cpp ${tag}`, draft: true, prerelease: true, make_latest: 'false',
      body: `beta 分支测试版，版本 ${version}。\n\n` +
        `源码提交：${context.sha}\n\n` +
        `已通过 Ubuntu 20.04 / NOI Linux 2.0 工具链的构建、GTK2 回归与安装检查：` +
        `https://github.com/${owner}/${repo}/actions/runs/${context.runId}\n\n` +
        '附件包含 amd64 .deb，以及仅包含 linux-noi-lazarus/ 的 ZIP 和 tar.gz 源码归档。测试版不会替代最新稳定版。\n\n' +
        `[打包与安装说明](https://github.com/${owner}/${repo}/blob/${tag}/docs/PACKAGING.md) · ` +
        `[NOI Linux 软件安装修复指南](https://github.com/${owner}/${repo}/blob/${tag}/docs/NOI-LINUX-SOFTWARE-INSTALL.md)`
    }));
  }
  const assets = await github.paginate(github.rest.repos.listReleaseAssets, {
    owner, repo, release_id: release.id, per_page: 100
  });
  for (const {name, data} of files) {
    const existing = assets.find(asset => asset.name === name);
    if (existing) {
      if (existing.state !== 'uploaded' || existing.size === 0) {
        if (!release.draft) throw new Error(`Incomplete published asset: ${name}.`);
        await github.rest.repos.deleteReleaseAsset({owner, repo, asset_id: existing.id});
      } else {
        continue;
      }
    }
    if (!release.draft) throw new Error('A published release is incomplete; refusing to change its assets.');
    await github.rest.repos.uploadReleaseAsset({
      owner, repo, release_id: release.id, name, data,
      headers: {'content-type': 'application/octet-stream', 'content-length': data.length}
    });
  }
  if (release.draft) {
    await github.rest.repos.updateRelease({
      owner, repo, release_id: release.id, draft: false, prerelease: true, make_latest: 'false'
    });
  }
  core.info(`Pre-release ready: https://github.com/${owner}/${repo}/releases/tag/${tag}`);
};
