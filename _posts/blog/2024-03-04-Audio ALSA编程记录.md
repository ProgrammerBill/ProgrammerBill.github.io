---
author: Bill
catalog: true
date: '2024-03-04'
guitartab: false
header-img: img/bill/header-posts/2024-01-24-header.png
hide: false
layout: post
life: false
stickie: false
summary: '"Audio ALSA编程记录"'
tags: []
title: Audio ALSA编程记录
---
# 1. 背景

去年一直在做Android的音频开发，接触了不少TinyAlsa的接口调用流程。而最近在调试Linux时，面对Alsa的接口时却一脸懵，因此有必要对这两类进行下总结。本文讨论的所有代码均为Android原生代码，[Android Code Search](https://cs.android.com/)中获取。

# 2. TinyAlsa

TinyAlsa是一个轻量级的 ALSA 替代品，专注于提供一个简单且易于使用的 API，用于音频捕获和播放。它旨在为嵌入式系统和应用提供最基本的音频接口，避免了 alsa-lib 的复杂性和庞大体积。在Android Audio HAL开发中，用于和驱动的直接交互。

目前TinyAlsa在Android SDK的external目录下，存在两个版本：

- tinyalsa
- tinyalsa_new

而在Android调试音频的神器，tinyplay,tinycap,tinymix等都出自tinyalsa仓库中。

## 2.1 音频播放

音频播放流程以tinyplay为例子, 先看main函数:

```c
int main(int argc, char **argv)
{
    FILE *file;
    struct riff_wave_header riff_wave_header;
    struct chunk_header chunk_header;
    struct chunk_fmt chunk_fmt;
    unsigned int device = 0;
    unsigned int card = 0;
    unsigned int period_size = 1024;
    unsigned int period_count = 4;
    char *filename;
    int more_chunks = 1;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s file.wav [-D card] [-d device] [-p period_size]"
                " [-n n_periods] \n", argv[0]);
        return 1;
    }

    filename = argv[1];
    file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Unable to open file '%s'\n", filename);
        return 1;
    }

    fread(&riff_wave_header, sizeof(riff_wave_header), 1, file);
    if ((riff_wave_header.riff_id != ID_RIFF) ||
        (riff_wave_header.wave_id != ID_WAVE)) {
        fprintf(stderr, "Error: '%s' is not a riff/wave file\n", filename);
        fclose(file);
        return 1;
    }

    do {
        fread(&chunk_header, sizeof(chunk_header), 1, file);

        switch (chunk_header.id) {
        case ID_FMT:
            fread(&chunk_fmt, sizeof(chunk_fmt), 1, file);
            /* If the format header is larger, skip the rest */
            if (chunk_header.sz > sizeof(chunk_fmt))
                fseek(file, chunk_header.sz - sizeof(chunk_fmt), SEEK_CUR);
            break;
        case ID_DATA:
            /* Stop looking for chunks */
            more_chunks = 0;
            chunk_header.sz = le32toh(chunk_header.sz);
            break;
        default:
            /* Unknown chunk, skip bytes */
            fseek(file, chunk_header.sz, SEEK_CUR);
        }
    } while (more_chunks);

    /* parse command line arguments */
    argv += 2;
    while (*argv) {
        if (strcmp(*argv, "-d") == 0) {
            argv++;
            if (*argv)
                device = atoi(*argv);
        }
        if (strcmp(*argv, "-p") == 0) {
            argv++;
            if (*argv)
                period_size = atoi(*argv);
        }
        if (strcmp(*argv, "-n") == 0) {
            argv++;
            if (*argv)
                period_count = atoi(*argv);
        }
        if (strcmp(*argv, "-D") == 0) {
            argv++;
            if (*argv)
                card = atoi(*argv);
        }
        if (*argv)
            argv++;
    }

    play_sample(file, card, device, chunk_fmt.num_channels, chunk_fmt.sample_rate,
                chunk_fmt.bits_per_sample, period_size, period_count, chunk_header.sz);

    fclose(file);

    return 0;
}
```

从上述代码可以得知：

- tinyplay默认只支持wav音频格式的播放。
- tinyplay默认输入参数包括：
    - `-D`指定声卡。声卡代表一个物理声卡或音频接口。在系统中，每个声卡都被分配一个唯一的编号（通常从0开始）。这些声卡可以是内置的，比如主板上的集成音频接口，或者是外部的，比如通过 USB 连接的音频接口。
    - `-d`指定设备。在 ALSA术语中，一个声卡可以有多个设备，每个设备代表一个特定的音频功能或接口。设备也是用唯一的编号来识别的。在 PCM 上下文中，一个设备可以是一个播放（输出）设备或一个录制（输入）设备。
    - `-p`指定`period_size`。`period_size`指的是一个周期（也称为缓冲区片段或帧组）中的帧数。在 ALSA 和 tinyalsa 中，一帧定义为所有声道的单个样本集合。例如，在立体声音频中，一个左声道和一个右声道的样本组合成一帧。
    - `-n`指定`period_count`。`period_count`指的是整个缓冲区包含的周期数量。整个缓冲区的大小等于周期大小乘以周期数。
- 主要逻辑在play_sample，继续分析


```c
void play_sample(FILE *file, unsigned int card, unsigned int device, unsigned int channels,
                 unsigned int rate, unsigned int bits, unsigned int period_size,
                 unsigned int period_count, uint32_t data_sz)
{
    struct pcm_config config;
    struct pcm *pcm;
    char *buffer;
    unsigned int size, read_sz;
    int num_read;

    memset(&config, 0, sizeof(config));
    config.channels = channels;
    config.rate = rate;
    config.period_size = period_size;
    config.period_count = period_count;
    if (bits == 32)
        config.format = PCM_FORMAT_S32_LE;
    else if (bits == 24)
        config.format = PCM_FORMAT_S24_3LE;
    else if (bits == 16)
        config.format = PCM_FORMAT_S16_LE;
    config.start_threshold = 0;
    config.stop_threshold = 0;
    config.silence_threshold = 0;
    //检查参数是否支持
    if (!sample_is_playable(card, device, channels, rate, bits, period_size, period_count)) {
        return;
    }
    //以给定的参数配置，打开声卡设备
    pcm = pcm_open(card, device, PCM_OUT, &config);
    //pcm_is_ready用于检查pcm->fd是否大于0。
    if (!pcm || !pcm_is_ready(pcm)) {
        fprintf(stderr, "Unable to open PCM device %u (%s)\n",
                device, pcm_get_error(pcm));
        return;
    }

    size = pcm_frames_to_bytes(pcm, pcm_get_buffer_size(pcm));
    buffer = malloc(size);
    if (!buffer) {
        fprintf(stderr, "Unable to allocate %d bytes\n", size);
        free(buffer);
        pcm_close(pcm);
        return;
    }

    printf("Playing sample: %u ch, %u hz, %u bit %u bytes\n", channels, rate, bits, data_sz);

    /* catch ctrl-c to shutdown cleanly */
    signal(SIGINT, stream_close);

    do {
        read_sz = size < data_sz ? size : data_sz;
        num_read = fread(buffer, 1, read_sz, file);
        if (num_read > 0) {
            if (pcm_write(pcm, buffer, num_read)) {
                fprintf(stderr, "Error playing sample\n");
                break;
            }
            data_sz -= num_read;
        }
    } while (!closing && num_read > 0 && data_sz > 0);

    if (!closing) {
        // drain the data in the ALSA ring buffer before closing the PCM device
        unsigned long sleep_time_in_us =
                (unsigned long) pcm_get_buffer_size(pcm) * 1000UL / ((unsigned long) rate / 1000UL);
        printf("Draining... Wait %lu us\n", sleep_time_in_us);
        usleep(sleep_time_in_us);
    }

    free(buffer);
    pcm_close(pcm);
}

```

- pcm_open: 打开音频设备，需要输入对应的声卡，设备，表明播放还是录制，以及pcm的音频参数配置`pcm_config`。
- pcm_write: 写音频数据到声卡
- pcm_close: 关闭音频设备


其中`pcm_config`的定义在asoundlib.h，如下所示：

```c
enum pcm_format {
    PCM_FORMAT_INVALID = -1,
    PCM_FORMAT_S16_LE = 0,  /* 16-bit signed */
    PCM_FORMAT_S32_LE,      /* 32-bit signed */
    PCM_FORMAT_S8,          /* 8-bit signed */
    PCM_FORMAT_S24_LE,      /* 24-bits in 4-bytes */
    PCM_FORMAT_S24_3LE,     /* 24-bits in 3-bytes */

    PCM_FORMAT_MAX,
};
struct pcm_config {
    unsigned int channels; //通道数
    unsigned int rate;//采样率
    unsigned int period_size;//周期大小
    unsigned int period_count;//周期数量
    enum pcm_format format; //pcm的格式，如上所示，包括16，32bit等

    /* Values to use for the ALSA start, stop and silence thresholds, and
     * silence size.  Setting any one of these values to 0 will cause the
     * default tinyalsa values to be used instead.
     * Tinyalsa defaults are as follows.
     *
     * start_threshold   : period_count * period_size
     * stop_threshold    : period_count * period_size
     * silence_threshold : 0
     * silence_size      : 0
     */
    unsigned int start_threshold;
    unsigned int stop_threshold;
    unsigned int silence_threshold;
    unsigned int silence_size;

    /* Minimum number of frames available before pcm_mmap_write() will actually
     * write into the kernel buffer. Only used if the stream is opened in mmap mode
     * (pcm_open() called with PCM_MMAP flag set).   Use 0 for default.
     */
    int avail_min;
};
```

- `start_threshold` 控制着 PCM 设备开始播放或录制音频数据前缓冲区中必须累积的最小帧数。对于播放设备来说，一旦缓冲区中的帧数达到 `start_threshold`，播放就会开始。对于录制设备，达到阈值后开始录制。
- `stop_threshold`控制着 PCM 设备停止播放或录制的条件。对于播放设备，当缓冲区中剩余的帧数小于 `stop_threshold` 时，播放将停止。对于录制设备，当录制的帧数达到 `stop_threshold` 时，录制会停止。
- `silence_threshold` 和 `silence_size` 与静音数据的处理相关。它们通常用于配置录制设备，在录制过程中处理静音或背景噪声。`silence_threshold` 定义了将多少帧视为静音数据，而 `silence_size` 可以定义在检测到静音数据时要采取的操作或处理的长度。

在pcm_open前，还调用了`sample_is_playable`用于检查是否能够进行播放

```c
//tinyplay.c
int sample_is_playable(unsigned int card, unsigned int device, unsigned int channels,
                        unsigned int rate, unsigned int bits, unsigned int period_size,
                        unsigned int period_count)
{
    struct pcm_params *params;
    int can_play;
 
    params = pcm_params_get(card, device, PCM_OUT);
    if (params == NULL) {
        fprintf(stderr, "Unable to open PCM device %u.\n", device);
        return 0;
    }

    can_play = check_param(params, PCM_PARAM_RATE, rate, "Sample rate", "Hz");
    can_play &= check_param(params, PCM_PARAM_CHANNELS, channels, "Sample", " channels");
    can_play &= check_param(params, PCM_PARAM_SAMPLE_BITS, bits, "Bitwidth", " bits");
    can_play &= check_param(params, PCM_PARAM_PERIOD_SIZE, period_size, "Period size", " frames");
    can_play &= check_param(params, PCM_PARAM_PERIODS, period_count, "Period count", " periods");

    pcm_params_free(params);

    return can_play;
}

int check_param(struct pcm_params *params, unsigned int param, unsigned int value,
                 char *param_name, char *param_unit)
{
    unsigned int min;
    unsigned int max;
    int is_within_bounds = 1;

    min = pcm_params_get_min(params, param);
    if (value < min) {
        fprintf(stderr, "%s is %u%s, device only supports >= %u%s\n", param_name, value,
                param_unit, min, param_unit);
        is_within_bounds = 0;
    }

    max = pcm_params_get_max(params, param);
    if (value > max) {
        fprintf(stderr, "%s is %u%s, device only supports <= %u%s\n", param_name, value,
                param_unit, max, param_unit);
        is_within_bounds = 0;
    }

    return is_within_bounds;
}


```

- `pcm_params_get`获取关于该声卡的参数，底层设计Alsa的接口，放在后续分析。
- 此处可以认为，`pcm_params_get`获取到了声卡的关于采样率，声道数，位宽，周期，周期数目等参数,并且可以通过`pcm_params_get_min`,`pcm_params_get_max`获取到最小值和最大值范围，当检查达到输入的参数不在范围以内，即可判断参数为不支持。

`pcm_is_ready`用于检查pcm->fd是否大于0，当调用`pcm_open`时，会调用底层接口打开节点，并对fd赋值。

音频录制的流程和播放相仿，只是从`pcm_open`选择了输入参数即可。

# 3. Alsa


alsa-lib（Advanced Linux Sound Architecture library）是Linux系统中的一个提供音频和MIDI（Musical Instrument Digital Interface）功能的库，它是ALSA音频系统的用户空间组件。alsa-lib的接口可以参考链接[alsa-lib](https://github.com/alsa-project/alsa-lib)


在alsa-lib中，音频播放流程大致如下：

1. 打开音频设备:
    - 使用snd_pcm_open()函数打开PCM（Pulse Code Modulation）设备。这个步骤涉及到指定设备名称（如"default"）和打开模式（播放或录制）。
2. 设置硬件参数（HW Params）:
    - 使用`snd_pcm_hw_params_any()初始化硬件参数结构。
    - 使用snd_pcm_hw_params_set_access()设置访问类型（通常是交错模式）。
    - 使用snd_pcm_hw_params_set_format()设置样本格式（如SND_PCM_FORMAT_S16_LE表示16位有符号小端）。
    - 使用snd_pcm_hw_params_set_rate_near()设置采样率（如44100Hz）。
    - 使用snd_pcm_hw_params_set_channels()设置声道数（如2代表立体声）。
    - 最后，使用snd_pcm_hw_params()将配置的硬件参数应用到PCM设备上。
3. 准备音频接口:
    - 使用snd_pcm_prepare()函数准备PCM设备，使之处于就绪状态，等待播放数据。
4. 写入音频数据进行播放:
    - 使用snd_pcm_writei()或snd_pcm_writen()函数将音频数据写入PCM设备进行播放。这些函数接受音频数据的缓冲区和需要写入的帧数。如果写入操作因为缓冲区满等原因而阻塞，这些函数会等待直到有足够的空间进行写入。
5. 处理XRUN（缓冲区下溢/过载）:
    - 如果发生XRUN（比如播放设备的缓冲区空了，没有足够的数据播放），需要检测并处理这种情况。通常，处理XRUN包括调用snd_pcm_prepare()重新准备设备，并重新开始数据的写入。
6. 音频播放完成:
    - 播放完成后，使用snd_pcm_drain()来停止PCM设备，并等待最后的音频数据播放完成。
。关闭音频设备:
    - 使用snd_pcm_close()关闭PCM设备释放资源。