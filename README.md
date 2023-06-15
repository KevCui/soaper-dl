# soaper-dl

> Download TV series and movies from [Soaper](https://soaper.tv/) in your terminal

## Table of Contents

- [Dependency](#dependency)
- [Installation](#installation)
- [How to use](#how-to-use)
  - [Usage](#usage)
  - [Example](#example)
  - [Advanced Usage](#advanced-usage)
- [Disclaimer](#disclaimer)
- [You may also like...](#you-may-also-like)

## Dependency

- [curl](https://curl.haxx.se/download.html)
- [jq](https://stedolan.github.io/jq/)
- [pup](https://github.com/EricChiang/pup)
- [fzf](https://github.com/junegunn/fzf)
- [ffmpeg](https://ffmpeg.org/download.html)

## How to use

### Usage

```
Usage:
  ./soaper-dl.sh [-n <name>] [-p <path>] [-e <num1,num2,num3-num4...>] [-l] [-s] [-d]

Options:
  -n <name>               TV series or Movie name
  -p <path>               media path, e.g: /tv_XXXXXXXX.html
                          ingored when "-n" is enabled
  -e <num1,num3-num4...>  optional, episode number to download
                          e.g: episode number "3.2" means Season 3 Episode 2
                          multiple episode numbers seperated by ","
                          episode range using "-"
  -l                      optional, list video or subtitle link without downloading
  -s                      optional, download subtitle only
  -d                      enable debug mode
  -h | --help             display this help message
```

### Example

- Search TV series or movies name and select the right one in `fzf`:

```bash
$ ./soaper-dl.sh -n 'game of'
  [/movie_mlkW68VGba.html][2023] The Game of Crowns: The Tudors
  [/movie_nXDEY29Dml.html][2023] Game of Love
  [/movie_LwD8MEPg9a.html][2023] Game of Deceit
  [/movie_zrYg3nbDL1.html][2022] A Game of Secrets
  [/movie_wY4GQ0Wgbe.html][2023] Game of Love
> [/tv_34OGB6G6Zl.html][2011-04-17] Game of Thrones
```

- If the media URI path is known, for instance, `/tv_34OGB6G6Zl.html` in the previous example is the path for `Game of Thrones`:

```bash
$ ./soaper-dl.sh -p /tv_34OGB6G6Zl.html
...
[2.1] 1.Winter is Coming
[2.2] 2.The Kingsroad
[2.3] 3.Lord Snow
[2.4] 4.Cripples, Bastards, and Broken Things
[2.5] 5.The Wolf and the Lion
[2.6] 6.A Golden Crown
[2.7] 7.You Win or You Die
[2.8] 8.The Pointy End
...
Which episode(s) to download:
```

- Download `Friends S01E01`:

```bash
$ ./soaper-dl.sh -p /tv_YxAgjOVGEL.html -e 1.1
[INFO] Downloading video 1.1...
```

The downloaded video will be present in the folder `~/<media_name>/`

- Support batch downloads: download `Friends S01E01` to `S01E05`:

```bash
$ ./soaper-dl.sh -p /tv_aTo2OTs.html -e 1.1,1.2,1.3,1.4,1.5
[INFO] Downloading video 1.1...
...
[INFO] Downloading video 1.2...
...
[INFO] Downloading video 1.3...
...
[INFO] Downloading video 1.4...
...
[INFO] Downloading video 1.5...
...
```

OR using episode range:

```bash
$ ./soaper-dl.sh -p /tv_aTo2OTs.html -e 1.1-1.5
[INFO] Downloading video 1.1...
...
[INFO] Downloading video 1.2...
...
[INFO] Downloading video 1.3...
...
[INFO] Downloading video 1.4...
...
[INFO] Downloading video 1.5...
...
```

:warning: The range option only works when the season number is the same. To download episodes in different seasons, for example: `... -e 1.1-1.5,2.2-2.8,3.1-3.5`

- Display only video link, used to pipe into `mpv` or other media player:

```bash
$ mpv "$(./soaper-dl.sh -p /tv_YxAgjOVGEL.html -e 1.1 -l)"
```

- Download subtitle only

```
./soaper-dl.sh -n 'game of thrones' -s
```

- Customize subtitle language

```bash
SOAPER_SUBTITLE_LANG=fr ./soaper-dl.sh -n 'game of thrones'
```

## Disclaimer

The purpose of this script is to download TV series episodes and movies in order to watch them later in case when Internet is not available. Please do NOT copy or distribute downloaded materials to any third party. Watch them and delete them afterwards. Please use this script at your own responsibility.

## You may also like...

### What to know when the new episode of your favorite TV series or movie will be released?

Check out this script [tvdb-cli](https://github.com/KevCui/tvdb-cli)

---

<a href="https://www.buymeacoffee.com/kevcui" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-orange.png" alt="Buy Me A Coffee" height="60px" width="217px"></a>