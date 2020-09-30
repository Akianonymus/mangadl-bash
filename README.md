<h1 align="center">Manga Downloader</h1>
<p align="center">
<a href="https://github.com/Akianonymus/mangadl-bash/stargazers"><img src="https://img.shields.io/github/stars/Akianonymus/mangadl-bash.svg?color=blueviolet&style=for-the-badge" alt="Stars"></a>
</p>
<p align="center">
<a href="https://www.codacy.com/manual/Akianonymus/mangadl-bash?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=Akianonymus/mangadl-bash&amp;utm_campaign=Badge_Grade"><img alt="Codacy grade" src="https://img.shields.io/codacy/grade/62f44daae6f548978d7d3daae5d6074c/master?style=for-the-badge"></a>
<a href="https://github.com/Akianonymus/mangadl-bash/actions"><img alt="Github Action Checks" src="https://img.shields.io/github/workflow/status/Akianonymus/mangadl-bash/Checks/master?label=CI%20Checks&style=for-the-badge"></a>
</p>
<p align="center">
<a href="https://github.com/Akianonymus/mangadl-bash/blob/master/LICENSE"><img src="https://img.shields.io/github/license/Akianonymus/gdrive-downloader.svg?style=for-the-badge" alt="License"></a>
</p>

> mangadl-bash is a collection of bash compliant scripts to download mangas from different sources.

- Minimal
- Search and download mangas
- Resume Interrupted downloads
- Easily batch download mangas
- Parallel downloading
- Pretty logging
- Easy to install and update
  - Self update
  - [Auto update](#updation)
  - Can be per-user and invoked per-shell, hence no root access required or global install with root access.

## Supported sources

- Manganelo / Mangakakalot
- Mangahub
- Mangafox / Fanfox
- Readmanhwa

## Table of Contents

- [Compatibility](#compatibility)
  - [Linux or MacOS](#linux-or-macos)
  - [Android](#android)
  - [iOS](#ios)
  - [Windows](#windows)
- [Installing and Updating](#installing-and-updating)
  - [Native Dependencies](#native-dependencies)
  - [Installation](#installation)
    - [Basic Method](#basic-method)
    - [Advanced Method](#advanced-method)
  - [Updation](#updation)
- [Usage](#usage)
  - [Download Script Custom Flags](#download-script-custom-flags)
  - [Multiple Inputs](#multiple-inputs)
  - [Resuming Interrupted Downloads](#resuming-interrupted-downloads)
- [Uninstall](#Uninstall)
- [Reporting Issues](#reporting-issues)
  - [Adding new sources](#adding-new-sources)
- [Contributing](#contributing)
- [License](#license)

## Compatibility

As this repo is bash compliant, there aren't many dependencies. See [Native Dependencies](#native-dependencies) after this section for explicitly required program list.

### Linux or MacOS

For Linux or MacOS, you hopefully don't need to configure anything extra, it should work by default.

### Android

Install [Termux](https://wiki.termux.com/wiki/Main_Page).

Then, `pkg install curl wget` and done.

Install convert too if you are going to use -c/--convert flag.

It's fully tested for all usecases of this script.

### iOS

Install [iSH](https://ish.app/)

While it has not been officially tested, but should work given the description of the app. Report if you got it working by creating an issue.

### Windows

Use [Windows Subsystem](https://docs.microsoft.com/en-us/windows/wsl/install-win10)

Again, it has not been officially tested on windows, there shouldn't be anything preventing it from working. Report if you got it working by creating an issue.

## Installing and Updating

### Native Dependencies

The script explicitly requires the following programs:

| Program   | Role In Script                                         |
| --------- | ------------------------------------------------------ |
| bash      | Execution of script ( version >= 4 )                   |
| curl      | Network requests for fetching manga details            |
| sleep     | To sleep                                               |
| wget      | Downloading images                                     |
| xargs     | For parallel downloading                               |
| mkdir     | To create folders                                      |
| rm        | To remove files and folders                            |
| grep      | Miscellaneous                                          |
| sed       | Miscellaneous                                          |
| zip       | For creating zip ( -z / --zip option )                 |
| convert   | For converting images ( -c / --convert option )        |

Note: zip and convert programs are optional, if not installed, then respective flags won't work, but rest of the script functions will be fine.

### Installation

You can install the script by automatic installation script provided in the repository.

Default values set by automatic installation script, which are changeable:

**Repo:** `Akianonymus/mangadl-bash`

**Command name:** `mangadl`

**Installation path:** `$HOME/.mangadl-bash`

**Source value:** `master`

**Shell file:** `.bashrc` or `.zshrc` or `.profile`

For custom command name, repo, shell file, etc, see advanced installation method.

Note: When global install is done, then standalone script is used, and split files are used in per-user per-shell installation.

**Now, for automatic install script, there are two ways:**

#### Basic Method

To install mangadl-bash in your system, you can run the below command:

```shell
curl --compressed -s https://raw.githubusercontent.com/Akianonymus/mangadl-bash/master/release/install | bash -s
```

and done.

#### Advanced Method

This section provides information on how to utilise the install script for custom usescases.

These are the flags that are available in the install script:

<details>

<summary>Click to expand</summary>

-   <strong>-p | --path <dir_name></strong>

    Custom path where you want to install the script.

    ---

-   <strong>-c | --cmd <command_name></strong>

    Custom command name, after installation, script will be available as the input argument.

    ---

-   <strong>-r | --repo <Username/reponame></strong>

    Install script from your custom repo, e.g --repo Akianonymus/mangadl-bash, make sure your repo file structure is same as official repo.

    ---

-   <strong>-B | --branch <branch_name></strong>

    Specify branch name for the github repo, applies to custom and default repo both.

    ---

-   <strong>-s | --shell-rc <shell_file></strong>

    Specify custom rc file, where PATH is appended, by default script detects .zshrc, .bashrc. and .profile.

    ---

-   <strong>-t | --time 'no of days'</strong>

    Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.

    Default: 5 ( 5 days )

    ---

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   <strong>-q | --quiet</strong>

    Only show critical error/sucess logs.

    ---

-   <strong>-U | --uninstall</strong>

    Uninstall the script and remove related files.\n

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

-   <strong>-h | --help</strong>

    Display usage instructions.

    ---

Now, run the script and use flags according to your usecase.

E.g:

```shell
curl --compressed -s https://raw.githubusercontent.com/Akianonymus/mangadl-bash/master/release/install | bash -s -- -r username/reponame -p somepath -s shell_file -c command_name -B branch_name
```

</details>

### Updation

If you have followed the automatic method to install the script, then you can automatically update the script.

There are two methods:

1.  Use the script itself to update the script.

    `mangadl -u or mangadl --update`

    This will update the script where it is installed.

    <strong>If you use the this flag without actually installing the script,</strong>

    <strong>e.g just by `bash mangadl.bash -u` then it will install the script or update if already installed.</strong>

1.  Run the installation script again.

    Yes, just run the installation script again as we did in install section, and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation,**
**e.g if you have installed the script with different repo, say `myrepo/mangadl-bash`, then the update will be also fetched from the same repo.**

## Usage

After installation, no more configuration is needed.

`mangadl manga_name/manga_url`

Script supports argument as mangaurl, or a manga_name.

Incase of mangaurl, it should be in supported providers, see utils folder for all providers.

Incase of search term, it will searched in the remote database and show results, choose accordingly and proceed.

Now, we have covered the basics, move on to the next section for some super useful features and usage, like specifying range, parallel downloads, etc.

### Download Script Custom Flags

These are the custom flags that are currently implemented:

-   <strong>-d | --directory</strong>

    Custom workspace folder where new mangas will be downloaded.

    ---

-   <strong>-s | --source 'name of source'</strong>

    Source where the input will be searched. See available sources in utils folder.

    To change default source, use mangadl -s default=sourcename

    ---

-   <strong>-n | --num 'no of searches to show'</strong>

    No. of searches to show, default is 10.

    To change default no of searches, use mangadl -n default='no of searches'\n

    ---

-   <strong>-p | --parallel <no_of_files_to_parallely_download></strong>

    Download multiple files in parallel.

    Note:

    - This command is only helpful if you are downloding many files which aren't big enough to utilise your full bandwidth, using it otherwise will not speed up your download and even error sometimes,
    - 5 to 10 value is recommended. If errors with a high value, use smaller number.
    - Beaware, this isn't magic, obviously it comes at a cost of increased cpu/ram utilisation as it forks multiple bash processes to download ( google how xargs works with -P option ).

    ---

-   <strong>-r | --range 'ranges'</strong>

    Note: Arguments are optional

    Custom range, can be given with this flag as argument, or if not given, then will be asked later in the script.

    If range is given with flag as an argument, the it is taken as postion of chapter of a specific manga.

    e.g: -r '1 5-10 11 15-last last', this will download chapter number 1, 5 to 10 and 11.

    Note:

      - 15-last type of range will pick from 15th number chapter to last.

      - If just last is given, then it will download last chapter.

      - In-case of 1-10 type of range, if last number ( i.e 10 ) exceeds total number of chapters, then all the rest chapters will be downloaded.

    ---

-   <strong>-c | --convert 'quality between 1 to 99'</strong>

    Decrease quality of images by the given percentage using convert ( imagemagick ) .\n

    Note: Output images are converted to jpg.

    ---

-   <strong>-z | --zip</strong>

    Create zip of downloaded images.

    ---

-   <strong>--upload</strong>

    Upload created zip on pixeldrain.com.

    ---

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   <strong>-u | --update</strong>

    Update the installed script in your system, if not installed, then install.

    ---

-   <strong>--uninstall</strong>

    Uninstall the installed script in your system.

    ---

-   <strong>--info</strong>

    Show detailed info, only if script is installed system wide.

    ---

-   <strong>-h | --help</strong>

    Display usage instructions.

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

### Multiple Inputs

You can use multiple inputs without any extra hassle.

Pass arguments normally, e.g: `mangadl manga1 manga2 manga_url1 manga_url2`

where manga1 and manga2 is manganame and rest two are urls of manga.

### Resuming Interrupted Downloads

Downloads interrupted either due to bad internet connection or manual interruption, can be resumed from the same position.

You can interrupt many times you want, it will resume ( hopefully ).

It will not download again if image is already present, thus avoiding bandwidth waste.

## Uninstall

If you have followed the automatic method to install the script, then you can automatically uninstall the script.

There are three methods:

1.  Automatic updates

    By default, script checks for update after 3 days. Use -t / --time flag of install script to modify the interval.

1.  Use the script itself to uninstall the script.

    `mangadl --uninstall`

    This will remove the script related files and remove path change from shell file.

1.  Run the installation script again with -U/--uninstall flag

    ```shell
    curl --compressed -s https://raw.githubusercontent.com/Akianonymus/mangadl-bash/master/release/install | bash -s --  --uninstall
    ```

    Yes, just run the installation script again with the flag and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation.**

## Reporting Issues

| Issues Status | [![GitHub issues](https://img.shields.io/github/issues/Akianonymus/mangadl-bash.svg?label=&style=for-the-badge)](https://GitHub.com/Akianonymus/mangadl-bash/issues/) | [![GitHub issues-closed](https://img.shields.io/github/issues-closed/Akianonymus/mangadl-bash.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/Akianonymus/mangadl-bash/issues?q=is%3Aissue+is%3Aclosed) |
| :-----------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

Use the [GitHub issue tracker](https://github.com/Akianonymus/mangadl-bash/issues) for any bugs or feature suggestions.

### Adding new sources

If you want support for a new source, then make a new issue along with the site url.

## Contributing

| Total Contributers | [![GitHub contributors](https://img.shields.io/github/contributors/Akianonymus/mangadl-bash.svg?style=for-the-badge&label=)](https://GitHub.com/Akianonymus/mangadl-bash/graphs/contributors/) |
| :----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

| Pull Requests | [![GitHub pull-requests](https://img.shields.io/github/issues-pr/Akianonymus/mangadl-bash.svg?label=&style=for-the-badge&color=orange)](https://GitHub.com/Akianonymus/mangadl-bash/issues?q=is%3Apr+is%3Aopen) | [![GitHub pull-requests closed](https://img.shields.io/github/issues-pr-closed/Akianonymus/mangadl-bash.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/Akianonymus/mangadl-bash/issues?q=is%3Apr+is%3Aclosed) |
| :-----------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

Submit patches to code or documentation as GitHub pull requests. Make sure to run merge.bash and format.bash before making a new pull request.

If using a code editor, then use shfmt plugin instead of format.bash

All shellcheck warnings should also successfully pass, if needs to be disabled, proper explanation is needed.

## License

[UNLICENSE](https://github.com/Akianonymus/mangadl-bash/blob/master/LICENSE)
