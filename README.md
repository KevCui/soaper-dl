# soap2day-dl

> Bash script to download TV series and movies from [soap2day](https://soap2day.to/)

## Dependency

- [curl](https://curl.haxx.se/download.html)
- [jq](https://stedolan.github.io/jq/)
- [pup](https://github.com/EricChiang/pup)
- [fzf](https://github.com/junegunn/fzf)

## How to use

```
Usage:
  ./soap2day-dl.sh [-n <name>] [-p <path>] [-e <num1,num2,num3-num4...>] [-l] [-s]

Options:
  -n <name>               TV series or Movie name
  -p <path>               Media path
                          e.g: /tv_XXXXXXXX.html
                          ingored when "-n" is enabled
  -e <num1,num3-num4...>  Optional, episode number to download
                          e.g: episode number "3.2" means Season 3 Episode 2
                          multiple episode numbers seperated by ","
                          episode range using "-"
  -l                      Optional, list video link only without downloading
  -s                      Optional, download subtitle only
  -h | --help             Display this help message
```

### Example

- Search TV series or movies name and select the right one in `fzf`:

```bash
$ ./soap2day-dl.sh -n 'game of'
  [/movie_aTo3Njk2Ow.html] Game of Death
  [/movie_aToxNTUwOw.html] Sherlock Holmes: A Game of Shadows
  [/tv_aToyMjUzOw.html] Game of Silence
> [/tv_aTo2Mjs.html] Game of Thrones
```

- If the media URI path is known, for instance, `/tv_aTo2Mjs.html` in the previous example is the path for `Game of Thrones`:

```bash
$ ./soap2day-dl.sh -p /tv_aTo2Mjs.html
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
$ ./soap2day-dl.sh -p /tv_aTo2OTs.html -e 1.1
[INFO] Downloading video 1.1...
```

The downloaded video will be present in the folder `~/<media_name>/`

- Support batch downloads: download `Friends S01E01` to `S01E05`:

```bash
$ ./soap2day-dl.sh -p /tv_aTo2OTs.html -e 1.1,1.2,1.3,1.4,1.5
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
$ ./soap2day-dl.sh -p /tv_aTo2OTs.html -e 1.1-1.5
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

- Display only video link, used to pipe into `mpv` or other media player:

```bash
$ mpv "$(./soap2day-dl.sh-dl.sh -p /tv_aTo2Mjs.html -e 1.1 -l)"
```

OR the interactive way:

```bash
$ mpv "$(./soap2day-dl.sh -n 'game of' -l | grep 'https://')"
```

## Disclaimer

The purpose of this script is to download TV series episodes and movies in order to watch them later in case when Internet is not available. Please do NOT copy or distribute downloaded materials to any third party. Watch them and delete them afterwards. Please use this script at your own responsibility.

## You may like...

### What to know when the new episode of your favorite TV series or movie will be released?

Check out this script [tvdb-cli](https://github.com/KevCui/tvdb-cli)

---

<a href="https://www.buymeacoffee.com/kevcui" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-orange.png" alt="Buy Me A Coffee" height="60px" width="217px"></a>