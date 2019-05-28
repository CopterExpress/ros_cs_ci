#!/usr/bin/env python3

# Generate and upload changelog

from git import Repo, exc
from github import Github
import os
import sys

upload_changelog = True

# Tracked repositories and their paths
# First entry in each pair is how the repository will appear in the changelog
# Second is the path relative to the script (or an absolute path, if that works)
TRACKED_REPOSITORIES = [
    ('Base repository', '.'),
    ('ROS Charging Station modules (ros_cs)', './ros_cs'),
    ('pymavlink with COEX patches', './pymavlink'),
    ('cmavnode with COEX patches', './cmavnode'),
    ('MAVLink library', './mavlink')
]


# Get changelog and start/end points
def get_repo_changelog(repo_path: str):
    print('Opening repository at {}'.format(repo_path))
    repo = Repo(repo_path)
    git = repo.git()
    try:
        print('Unshallowing repository at {}'.format(repo_path))
        git.fetch('--unshallow', '--tags')
    except exc.GitCommandError:
        print('Repository already unshallowed')
    print('Attempting to get previous tag')
    log_args = []
    try:
        base_tag = git.describe('--tags', '--abbrev=0', '{}^'.format('HEAD'))
        print('Base tag set to {}'.format(base_tag))
        history_brackets = (base_tag, 'HEAD')
        log_args += ['{}...{}'.format(base_tag, current_tag)]
    except exc.GitCommandError:
        print('No tags found, ')
        history_brackets = ('initial commit', 'HEAD')
    log_args += ['--pretty=format:* %H %s *(%an)*']
    changelog = git.log(*log_args)
    return history_brackets, changelog


try:
    current_tag = os.environ['TRAVIS_TAG']
    if current_tag == '':
        current_tag = 'HEAD'
        upload_changelog = False
    print('TRAVIS_TAG is set to {}'.format(current_tag))
except KeyError:
    print('TRAVIS_TAG not set - not uploading changelog')
    current_tag = 'HEAD'
    upload_changelog = False

try:
    api_key = os.environ['GITHUB_OAUTH_TOKEN']
except KeyError:
    print('GITHUB_OAUTH_TOKEN not set - not uploading changelog')
    api_key = None
    upload_changelog = False

try:
    target_repo = os.environ['RELEASES_REPO']
except KeyError:
    print('RELEASES_REPO not set - cannot determine remote repository')
    target_repo = ''
    exit(1)

complete_changelog = ''
for (repo_name, repo_path) in TRACKED_REPOSITORIES:
    brackets, changelog = get_repo_changelog(repo_path)
    print('Changelog for {}:\n{}'.format(repo_name, changelog))
    complete_changelog += '## {}\n\nChanges between {} and {}:\n\n{}\n\n'.format(repo_name,
                                                                                 brackets[0],
                                                                                 brackets[1],
                                                                                 changelog)


# Only interact with Github if uploading is enabled
if upload_changelog:
    gh = Github(api_key)
    gh_repo = gh.get_repo(target_repo)
    # Get all releases and find ours by its tag name
    gh_release = None
    for release in gh_repo.get_releases():
        if release.tag_name == current_tag:
            gh_release = release
    if gh_release is None:
        # We could not find the correct release, so here's our last resort. It will most likely fail.
        gh_release = gh_repo.get_release(current_tag)
    gh_body = gh_release.body
    if gh_body is None:
        gh_body = ''
    gh_body = '{}\n{}'.format(gh_body, complete_changelog)
    print('New release body: {}'.format(gh_body))
    gh_release.update_release(gh_release.tag_name, gh_body, draft=True, prerelease=True,
                              tag_name=gh_release.tag_name, target_commitish=gh_release.target_commitish)
