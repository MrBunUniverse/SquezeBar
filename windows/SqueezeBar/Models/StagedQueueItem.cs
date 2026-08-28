using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;

namespace SqueezeBar.Models;

public class StagedQueueItem : INotifyPropertyChanged
{
    public Guid Id { get; } = Guid.NewGuid();
    public string FilePath { get; }
    public long OriginalSize { get; }
    public MediaType MediaType { get; }

    private double _customQuality = 0.80;
    public double CustomQuality
    {
        get => _customQuality;
        set { _customQuality = value; OnPropertyChanged(); OnPropertyChanged(nameof(CustomSettingSummary)); }
    }

    private double _customResolutionScale = 1.0;
    public double CustomResolutionScale
    {
        get => _customResolutionScale;
        set { _customResolutionScale = value; OnPropertyChanged(); OnPropertyChanged(nameof(CustomSettingSummary)); }
    }

    private ImageFormatPolicy _customImageFormat = ImageFormatPolicy.PreserveOriginal;
    public ImageFormatPolicy CustomImageFormat
    {
        get => _customImageFormat;
        set { _customImageFormat = value; OnPropertyChanged(); OnPropertyChanged(nameof(CustomSettingSummary)); }
    }

    private VideoCodecPreference _customVideoCodec = VideoCodecPreference.HEVC;
    public VideoCodecPreference CustomVideoCodec
    {
        get => _customVideoCodec;
        set { _customVideoCodec = value; OnPropertyChanged(); }
    }

    private TargetSizeMode _customTargetSizeMode = TargetSizeMode.Off;
    public TargetSizeMode CustomTargetSizeMode
    {
        get => _customTargetSizeMode;
        set { _customTargetSizeMode = value; OnPropertyChanged(); OnPropertyChanged(nameof(CustomSettingSummary)); }
    }

    private double _customTargetSizeMB = 25.0;
    public double CustomTargetSizeMB
    {
        get => _customTargetSizeMB;
        set { _customTargetSizeMB = value; OnPropertyChanged(); OnPropertyChanged(nameof(CustomSettingSummary)); }
    }

    private bool _stripMetadata = true;
    public bool StripMetadata
    {
        get => _stripMetadata;
        set { _stripMetadata = value; OnPropertyChanged(); }
    }

    public string FileName => Path.GetFileName(FilePath);
    public string Extension => Path.GetExtension(FilePath).TrimStart('.').ToUpperInvariant();

    public string FormattedOriginalSize
    {
        get
        {
            if (OriginalSize < 1024) return $"{OriginalSize} B";
            if (OriginalSize < 1024 * 1024) return $"{OriginalSize / 1024.0:F1} KB";
            if (OriginalSize < 1024 * 1024 * 1024) return $"{OriginalSize / (1024.0 * 1024):F1} MB";
            return $"{OriginalSize / (1024.0 * 1024 * 1024):F2} GB";
        }
    }

    public string CustomSettingSummary
    {
        get
        {
            var parts = new System.Collections.Generic.List<string>();
            if (CustomTargetSizeMode != TargetSizeMode.Off)
            {
                var targetBytes = CustomTargetSizeMode.GetTargetBytes(CustomTargetSizeMB);
                if (targetBytes.HasValue)
                {
                    parts.Add($"{targetBytes.Value / (1024 * 1024)}MB Limit");
                }
            }
            parts.Add($"{(int)(CustomQuality * 100)}% Q");
            if (CustomResolutionScale < 0.99)
            {
                parts.Add($"{(int)(CustomResolutionScale * 100)}% Scale");
            }
            return string.Join(" • ", parts);
        }
    }

    public StagedQueueItem(string filePath, long originalSize, MediaType mediaType, CompressionConfiguration baseConfig)
    {
        FilePath = filePath;
        OriginalSize = originalSize;
        MediaType = mediaType;

        CustomQuality = mediaType switch
        {
            MediaType.Image => baseConfig.ImageQuality,
            MediaType.Video => baseConfig.VideoQuality,
            _ => 0.80
        };

        CustomResolutionScale = mediaType switch
        {
            MediaType.Image => baseConfig.ImageResolutionScale,
            MediaType.Video => baseConfig.VideoResolutionScale,
            _ => 1.0
        };

        CustomImageFormat = baseConfig.ImageFormatPolicy;
        CustomVideoCodec = baseConfig.VideoCodec;
        CustomTargetSizeMode = baseConfig.TargetSizeMode;
        CustomTargetSizeMB = baseConfig.CustomTargetSizeMB;
        StripMetadata = baseConfig.StripMetadata;
    }

    public CompressionConfiguration BuildConfiguration(CompressionConfiguration baseConfig)
    {
        var config = baseConfig.Clone();
        config.ImageQuality = CustomQuality;
        config.ImageResolutionScale = CustomResolutionScale;
        config.ImageFormatPolicy = CustomImageFormat;
        config.VideoQuality = CustomQuality;
        config.VideoResolutionScale = CustomResolutionScale;
        config.VideoCodec = CustomVideoCodec;
        config.TargetSizeMode = CustomTargetSizeMode;
        config.CustomTargetSizeMB = CustomTargetSizeMB;
        config.StripMetadata = StripMetadata;
        return config;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    protected void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
