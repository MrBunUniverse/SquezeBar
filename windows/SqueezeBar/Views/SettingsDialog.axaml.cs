using Avalonia.Controls;
using Avalonia.Interactivity;
using SqueezeBar.Models;
using SqueezeBar.Services;

namespace SqueezeBar.Views;

public partial class SettingsDialog : Window
{
    private readonly CompressionConfiguration _config;

    public SettingsDialog()
    {
        InitializeComponent();
        _config = AppStateManager.Shared.BaseConfig;

        QualitySlider.Value = _config.ImageQuality;
        QualityValueLabel.Text = $"{(int)(_config.ImageQuality * 100)}%";
        QualitySlider.PropertyChanged += (s, e) =>
        {
            if (e.Property.Name == nameof(Slider.Value))
            {
                QualityValueLabel.Text = $"{(int)(QualitySlider.Value * 100)}%";
            }
        };

        ImageFormatBox.SelectedIndex = _config.ImageFormatPolicy switch
        {
            ImageFormatPolicy.ModernWebP => 1,
            ImageFormatPolicy.WebJPEG => 2,
            _ => 0
        };

        VideoCodecBox.SelectedIndex = _config.VideoCodec switch
        {
            VideoCodecPreference.H264 => 1,
            VideoCodecPreference.AnimatedGIF => 2,
            _ => 0
        };

        TargetSizeBox.SelectedIndex = _config.TargetSizeMode switch
        {
            TargetSizeMode.Discord25 => 1,
            TargetSizeMode.Email10 => 2,
            TargetSizeMode.Discord50 => 3,
            _ => 0
        };

        SuffixTextBox.Text = _config.OutputSuffix;
        StripMetadataCheck.IsChecked = _config.StripMetadata;
    }

    private void SaveButton_Click(object? sender, RoutedEventArgs e)
    {
        _config.ImageQuality = QualitySlider.Value;
        _config.ImageFormatPolicy = ImageFormatBox.SelectedIndex switch
        {
            1 => ImageFormatPolicy.ModernWebP,
            2 => ImageFormatPolicy.WebJPEG,
            _ => ImageFormatPolicy.PreserveOriginal
        };

        _config.VideoCodec = VideoCodecBox.SelectedIndex switch
        {
            1 => VideoCodecPreference.H264,
            2 => VideoCodecPreference.AnimatedGIF,
            _ => VideoCodecPreference.HEVC
        };

        _config.TargetSizeMode = TargetSizeBox.SelectedIndex switch
        {
            1 => TargetSizeMode.Discord25,
            2 => TargetSizeMode.Email10,
            3 => TargetSizeMode.Discord50,
            _ => TargetSizeMode.Off
        };

        _config.OutputSuffix = string.IsNullOrWhiteSpace(SuffixTextBox.Text) ? "_squeezed" : SuffixTextBox.Text.Trim();
        _config.StripMetadata = StripMetadataCheck.IsChecked ?? true;

        Close();
    }
}
