using System;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using SqueezeBar.Models;

namespace SqueezeBar.Views;

public partial class QueueItemSettingsDialog : Window
{
    private readonly StagedQueueItem _item;

    public QueueItemSettingsDialog()
    {
        InitializeComponent();
        _item = new StagedQueueItem("Sample.png", 1024 * 1024, MediaType.Image, new CompressionConfiguration());
    }

    public QueueItemSettingsDialog(StagedQueueItem item)
    {
        InitializeComponent();
        _item = item;

        FileNameText.Text = item.FileName;
        FileSizeText.Text = $"{item.FormattedOriginalSize} • {item.Extension.ToUpper().TrimStart('.')}";

        QualitySlider.Value = item.CustomQuality;
        QualityPercentText.Text = $"{(int)(item.CustomQuality * 100)}%";
        QualitySlider.PropertyChanged += (s, e) =>
        {
            if (e.Property.Name == nameof(Slider.Value))
            {
                _item.CustomQuality = QualitySlider.Value;
                QualityPercentText.Text = $"{(int)(QualitySlider.Value * 100)}%";
            }
        };

        StripMetadataCheck.IsChecked = item.StripMetadata;
        StripMetadataCheck.IsCheckedChanged += (s, e) =>
        {
            _item.StripMetadata = StripMetadataCheck.IsChecked ?? true;
        };

        // Media Type Adaptation
        switch (item.MediaType)
        {
            case MediaType.Video:
                QualityTitleText.Text = "Video Quality";
                ImageFormatPanel.IsVisible = false;
                VideoCodecPanel.IsVisible = true;
                AudioBitratePanel.IsVisible = false;
                PdfDpiPanel.IsVisible = false;
                ResolutionScalePanel.IsVisible = true;

                VideoCodecCombo.SelectedIndex = item.CustomVideoCodec switch
                {
                    VideoCodecPreference.H264 => 1,
                    VideoCodecPreference.AnimatedGIF => 2,
                    _ => 0
                };
                VideoCodecCombo.SelectionChanged += (s, e) =>
                {
                    _item.CustomVideoCodec = VideoCodecCombo.SelectedIndex switch
                    {
                        1 => VideoCodecPreference.H264,
                        2 => VideoCodecPreference.AnimatedGIF,
                        _ => VideoCodecPreference.HEVC
                    };
                };
                break;

            case MediaType.Audio:
                QualityTitleText.Text = "Audio Bitrate";
                ImageFormatPanel.IsVisible = false;
                VideoCodecPanel.IsVisible = false;
                AudioBitratePanel.IsVisible = true;
                PdfDpiPanel.IsVisible = false;
                ResolutionScalePanel.IsVisible = false;

                AudioBitrateCombo.SelectedIndex = item.CustomAudioBitrate switch
                {
                    AudioBitratePreference.K64 => 0,
                    AudioBitratePreference.K128 => 1,
                    AudioBitratePreference.K256 => 3,
                    AudioBitratePreference.K320 => 4,
                    _ => 2
                };
                AudioBitrateCombo.SelectionChanged += (s, e) =>
                {
                    _item.CustomAudioBitrate = AudioBitrateCombo.SelectedIndex switch
                    {
                        0 => AudioBitratePreference.K64,
                        1 => AudioBitratePreference.K128,
                        3 => AudioBitratePreference.K256,
                        4 => AudioBitratePreference.K320,
                        _ => AudioBitratePreference.K192
                    };
                };
                break;

            case MediaType.Pdf:
                QualityTitleText.Text = "Image Compression";
                ImageFormatPanel.IsVisible = false;
                VideoCodecPanel.IsVisible = false;
                AudioBitratePanel.IsVisible = false;
                PdfDpiPanel.IsVisible = true;
                ResolutionScalePanel.IsVisible = false;

                UpdatePdfDpiButtons(item.CustomPdfDpi switch
                {
                    72 => PdfDpi72Btn,
                    200 => PdfDpi200Btn,
                    300 => PdfDpi300Btn,
                    _ => PdfDpi150Btn
                });
                break;

            default: // Images
                QualityTitleText.Text = "Image Quality";
                ImageFormatPanel.IsVisible = true;
                VideoCodecPanel.IsVisible = false;
                AudioBitratePanel.IsVisible = false;
                PdfDpiPanel.IsVisible = false;
                ResolutionScalePanel.IsVisible = true;

                ImageFormatCombo.SelectedIndex = item.CustomImageFormat switch
                {
                    ImageFormatPolicy.ModernWebP => 0,
                    ImageFormatPolicy.WebJPEG => 1,
                    _ => 2
                };
                ImageFormatCombo.SelectionChanged += (s, e) =>
                {
                    _item.CustomImageFormat = ImageFormatCombo.SelectedIndex switch
                    {
                        0 => ImageFormatPolicy.ModernWebP,
                        1 => ImageFormatPolicy.WebJPEG,
                        _ => ImageFormatPolicy.PreserveOriginal
                    };
                };
                break;
        }

        // Initialize Scale Button State
        if (Math.Abs(item.CustomResolutionScale - 0.75) < 0.05) UpdateScaleButtons(Scale75Btn);
        else if (Math.Abs(item.CustomResolutionScale - 0.50) < 0.05) UpdateScaleButtons(Scale50Btn);
        else if (Math.Abs(item.CustomResolutionScale - 0.25) < 0.05) UpdateScaleButtons(Scale25Btn);
        else UpdateScaleButtons(Scale100Btn);

        // Initialize Target Limit State
        switch (item.CustomTargetSizeMode)
        {
            case TargetSizeMode.Discord25: UpdateLimitButtons(Limit25Btn); break;
            case TargetSizeMode.Email10: UpdateLimitButtons(Limit10Btn); break;
            case TargetSizeMode.Discord50: UpdateLimitButtons(Limit50Btn); break;
            default: UpdateLimitButtons(LimitOffBtn); break;
        }
    }

    // Scale Handlers
    private void Scale100_Click(object? sender, RoutedEventArgs e) { _item.CustomResolutionScale = 1.0; UpdateScaleButtons(Scale100Btn); }
    private void Scale75_Click(object? sender, RoutedEventArgs e) { _item.CustomResolutionScale = 0.75; UpdateScaleButtons(Scale75Btn); }
    private void Scale50_Click(object? sender, RoutedEventArgs e) { _item.CustomResolutionScale = 0.50; UpdateScaleButtons(Scale50Btn); }
    private void Scale25_Click(object? sender, RoutedEventArgs e) { _item.CustomResolutionScale = 0.25; UpdateScaleButtons(Scale25Btn); }

    private void UpdateScaleButtons(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(AppState.Shared.AccentColorHex);
        var inactiveFg = SolidColorBrush.Parse("#A0A0B0");

        foreach (var btn in new[] { Scale100Btn, Scale75Btn, Scale50Btn, Scale25Btn })
        {
            btn.Background = inactive;
            btn.Foreground = inactiveFg;
            btn.BorderBrush = SolidColorBrush.Parse("#2D2D32");
            btn.FontWeight = FontWeight.Normal;
        }
        activeBtn.Background = activeBg;
        activeBtn.Foreground = Brushes.Black;
        activeBtn.BorderBrush = Brushes.Transparent;
        activeBtn.FontWeight = FontWeight.SemiBold;
    }

    // Limit Handlers
    private void LimitOff_Click(object? sender, RoutedEventArgs e) { _item.CustomTargetSizeMode = TargetSizeMode.Off; UpdateLimitButtons(LimitOffBtn); }
    private void Limit25_Click(object? sender, RoutedEventArgs e) { _item.CustomTargetSizeMode = TargetSizeMode.Discord25; UpdateLimitButtons(Limit25Btn); }
    private void Limit10_Click(object? sender, RoutedEventArgs e) { _item.CustomTargetSizeMode = TargetSizeMode.Email10; UpdateLimitButtons(Limit10Btn); }
    private void Limit50_Click(object? sender, RoutedEventArgs e) { _item.CustomTargetSizeMode = TargetSizeMode.Discord50; UpdateLimitButtons(Limit50Btn); }

    private void UpdateLimitButtons(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(AppState.Shared.AccentColorHex);
        var inactiveFg = SolidColorBrush.Parse("#A0A0B0");

        foreach (var btn in new[] { LimitOffBtn, Limit25Btn, Limit10Btn, Limit50Btn })
        {
            btn.Background = inactive;
            btn.Foreground = inactiveFg;
            btn.BorderBrush = SolidColorBrush.Parse("#2D2D32");
            btn.FontWeight = FontWeight.Normal;
        }
        activeBtn.Background = activeBg;
        activeBtn.Foreground = Brushes.Black;
        activeBtn.BorderBrush = Brushes.Transparent;
        activeBtn.FontWeight = FontWeight.SemiBold;
    }

    // PDF DPI Handlers
    private void PdfDpi72_Click(object? sender, RoutedEventArgs e) { _item.CustomPdfDpi = 72; UpdatePdfDpiButtons(PdfDpi72Btn); }
    private void PdfDpi150_Click(object? sender, RoutedEventArgs e) { _item.CustomPdfDpi = 150; UpdatePdfDpiButtons(PdfDpi150Btn); }
    private void PdfDpi200_Click(object? sender, RoutedEventArgs e) { _item.CustomPdfDpi = 200; UpdatePdfDpiButtons(PdfDpi200Btn); }
    private void PdfDpi300_Click(object? sender, RoutedEventArgs e) { _item.CustomPdfDpi = 300; UpdatePdfDpiButtons(PdfDpi300Btn); }

    private void UpdatePdfDpiButtons(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(AppState.Shared.AccentColorHex);
        var inactiveFg = SolidColorBrush.Parse("#A0A0B0");

        foreach (var btn in new[] { PdfDpi72Btn, PdfDpi150Btn, PdfDpi200Btn, PdfDpi300Btn })
        {
            btn.Background = inactive;
            btn.Foreground = inactiveFg;
            btn.BorderBrush = SolidColorBrush.Parse("#2D2D32");
            btn.FontWeight = FontWeight.Normal;
        }
        activeBtn.Background = activeBg;
        activeBtn.Foreground = Brushes.Black;
        activeBtn.BorderBrush = Brushes.Transparent;
        activeBtn.FontWeight = FontWeight.SemiBold;
    }

    private void Done_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }
}
