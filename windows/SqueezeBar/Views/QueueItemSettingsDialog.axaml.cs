using System;
using Avalonia.Controls;
using Avalonia.Interactivity;
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
        FileSizeText.Text = $"{item.FormattedOriginalSize} • {item.Extension}";

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

        FormatComboBox.SelectedIndex = item.CustomImageFormat switch
        {
            ImageFormatPolicy.ModernWebP => 1,
            ImageFormatPolicy.WebJPEG => 2,
            _ => 0
        };

        FormatComboBox.SelectionChanged += (s, e) =>
        {
            _item.CustomImageFormat = FormatComboBox.SelectedIndex switch
            {
                1 => ImageFormatPolicy.ModernWebP,
                2 => ImageFormatPolicy.WebJPEG,
                _ => ImageFormatPolicy.PreserveOriginal
            };
        };
    }

    private void Scale100_Click(object? sender, RoutedEventArgs e) => _item.CustomResolutionScale = 1.0;
    private void Scale75_Click(object? sender, RoutedEventArgs e) => _item.CustomResolutionScale = 0.75;
    private void Scale50_Click(object? sender, RoutedEventArgs e) => _item.CustomResolutionScale = 0.50;
    private void Scale25_Click(object? sender, RoutedEventArgs e) => _item.CustomResolutionScale = 0.25;

    private void LimitOff_Click(object? sender, RoutedEventArgs e) => _item.CustomTargetSizeMode = TargetSizeMode.Off;
    private void Limit25_Click(object? sender, RoutedEventArgs e) => _item.CustomTargetSizeMode = TargetSizeMode.Discord25;
    private void Limit10_Click(object? sender, RoutedEventArgs e) => _item.CustomTargetSizeMode = TargetSizeMode.Email10;
    private void Limit50_Click(object? sender, RoutedEventArgs e) => _item.CustomTargetSizeMode = TargetSizeMode.Discord50;

    private void Done_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }
}
