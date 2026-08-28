using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using SqueezeBar.Models;
using SqueezeBar.Services;

namespace SqueezeBar.Views;

public partial class MainWindow : Window
{
    private FloatingBasketWindow? _floatingBasket;
    private readonly AppState _state = AppState.Shared;

    // macOS-style theme name labels
    private static readonly (string hex, string label)[] ThemeSwatches =
    {
        ("#00D2FF", "Cyan"),
        ("#00E676", "Emerald"),
        ("#A855F7", "Purple"),
        ("#FF9500", "Amber"),
        ("#FF2D55", "Rose"),
        ("#007AFF", "Blue"),
    };

    public MainWindow()
    {
        InitializeComponent();

        StagedQueueItemsList.ItemsSource = _state.StagedQueue;
        HistoryItemsList.ItemsSource = _state.History;
        ActiveJobsList.ItemsSource = _state.ActiveJobs;
        WatchedFoldersList.ItemsSource = _state.WatchedFolders;

        _state.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(_state.FormattedTotalSaved))
            {
                SavedStatsText.Text = $"{_state.FormattedTotalSaved} Saved";
                LifetimeSavedText.Text = _state.FormattedTotalSaved;
            }
            else if (e.PropertyName == nameof(_state.TotalFilesSqueezed))
            {
                LifetimeFilesText.Text = $"{_state.TotalFilesSqueezed} files";
            }
            else if (e.PropertyName == nameof(_state.StagedQueueCountText))
            {
                QueueHeaderTitle.Text = _state.StagedQueueCountText;
                SqueezeAllBtn.Content = _state.StagedQueue.Count > 0 ? $"Squeeze All ({_state.StagedQueue.Count})" : "Squeeze All";
                EmptyQueueHint.IsVisible = _state.StagedQueue.Count == 0;
            }
            else if (e.PropertyName == nameof(_state.IsProcessing))
            {
                ProcessingBadge.IsVisible = _state.IsProcessing;
                ActiveJobsBorder.IsVisible = _state.ActiveJobs.Any(j => !j.IsCompleted);
                FooterStatusText.Text = _state.IsProcessing ? "Optimizing..." : "Ready";
            }
            else if (e.PropertyName == nameof(_state.ImageSummaryText))
            {
                var fmt = _state.ImageFormatPolicy switch
                {
                    ImageFormatPolicy.ModernWebP => "WebP",
                    ImageFormatPolicy.WebJPEG => "JPEG",
                    _ => "Original"
                };
                ImagesTileFormat.Text = fmt;
                ImagesTileQuality.Text = $"{_state.ImageQualityPercent}% Q · {(int)(_state.ImageResolutionScale * 100)}%";
            }
            else if (e.PropertyName == nameof(_state.VideoSummaryText))
            {
                VideoTileCodec.Text = _state.VideoCodec.ToString();
                VideoTileQuality.Text = $"{_state.VideoQualityPercent}% Q · {(int)(_state.VideoResolutionScale * 100)}%";
            }
            else if (e.PropertyName == nameof(_state.AudioSummaryText))
            {
                AudioTileBitrate.Text = $"{_state.AudioBitrate.ToString().TrimStart('K')} kbps";
            }
            else if (e.PropertyName == nameof(_state.PdfSummaryText))
            {
                PdfTileDpi.Text = $"{_state.PdfDpi} DPI";
            }
        };

        // Sliders
        ImgQualitySlider.Value = _state.ImageQuality;
        ImgQualitySlider.PropertyChanged += (s, e) =>
        {
            if (e.Property.Name == nameof(Slider.Value))
            {
                _state.ImageQuality = ImgQualitySlider.Value;
                ImgQualityLabel.Text = $"{_state.ImageQualityPercent}%";
            }
        };

        VidQualitySlider.Value = _state.VideoQuality;
        VidQualitySlider.PropertyChanged += (s, e) =>
        {
            if (e.Property.Name == nameof(Slider.Value))
            {
                _state.VideoQuality = VidQualitySlider.Value;
                VidQualityLabel.Text = $"{_state.VideoQualityPercent}%";
            }
        };

        // Format Combos
        ImgFormatCombo.SelectedIndex = 0;
        ImgFormatCombo.SelectionChanged += (s, e) =>
        {
            _state.ImageFormatPolicy = ImgFormatCombo.SelectedIndex switch
            {
                0 => ImageFormatPolicy.ModernWebP,
                1 => ImageFormatPolicy.WebJPEG,
                _ => ImageFormatPolicy.PreserveOriginal
            };
        };

        VidCodecCombo.SelectedIndex = 0;
        VidCodecCombo.SelectionChanged += (s, e) =>
        {
            _state.VideoCodec = VidCodecCombo.SelectedIndex switch
            {
                1 => VideoCodecPreference.H264,
                2 => VideoCodecPreference.AnimatedGIF,
                _ => VideoCodecPreference.HEVC
            };
        };

        AudioBitrateCombo.SelectedIndex = 2;
        AudioBitrateCombo.SelectionChanged += (s, e) =>
        {
            _state.AudioBitrate = AudioBitrateCombo.SelectedIndex switch
            {
                0 => AudioBitratePreference.K64,
                1 => AudioBitratePreference.K128,
                3 => AudioBitratePreference.K256,
                4 => AudioBitratePreference.K320,
                _ => AudioBitratePreference.K192
            };
        };

        PdfGrayscaleCheck.IsCheckedChanged += (s, e) => _state.PdfGrayscale = PdfGrayscaleCheck.IsChecked ?? false;

        SettingsSuffixBox.PropertyChanged += (s, e) =>
        {
            if (e.Property.Name == nameof(TextBox.Text))
                _state.OutputSuffix = SettingsSuffixBox.Text?.Trim() ?? "_squeezed";
        };

        ReplaceOriginalCheck.IsCheckedChanged += (s, e) => _state.ReplaceOriginal = ReplaceOriginalCheck.IsChecked ?? false;
        StripMetadataCheck.IsCheckedChanged += (s, e) => _state.StripMetadata = StripMetadataCheck.IsChecked ?? true;

        // Drag & Drop
        QuickDropBorder.AddHandler(DragDrop.DropEvent, OnQuickDrop);
        QuickDropBorder.AddHandler(DragDrop.DragOverEvent, OnDragOver);
        StagedQueueBorder.AddHandler(DragDrop.DropEvent, OnStagedDrop);
        StagedQueueBorder.AddHandler(DragDrop.DragOverEvent, OnDragOver);

        EmptyQueueHint.IsVisible = _state.StagedQueue.Count == 0;
    }

    // ── Tab Navigation ──
    private void ActivityTab_Click(object? sender, RoutedEventArgs e)
    {
        _state.SelectedTab = PopoverTab.Activity;
        ActivityTabPanel.IsVisible = true;
        SettingsTabPanel.IsVisible = false;
        ActivityTabBtn.Background = SolidColorBrush.Parse("#2A2A2F");
        ActivityTabBtn.BorderBrush = SolidColorBrush.Parse("#353539");
        SettingsTabBtn.Background = Brushes.Transparent;
    }

    private void SettingsTab_Click(object? sender, RoutedEventArgs e)
    {
        _state.SelectedTab = PopoverTab.Settings;
        ActivityTabPanel.IsVisible = false;
        SettingsTabPanel.IsVisible = true;
        SettingsTabBtn.Background = SolidColorBrush.Parse("#2A2A2F");
        ActivityTabBtn.Background = Brushes.Transparent;
        ActivityTabBtn.BorderBrush = Brushes.Transparent;
    }

    // ── Category Tile Selection (Toggle Drawer) ──
    private void SelectImagesCategory_Click(object? sender, RoutedEventArgs e) => ToggleCategory(MediaCategory.Images);
    private void SelectVideoCategory_Click(object? sender, RoutedEventArgs e) => ToggleCategory(MediaCategory.Video);
    private void SelectAudioCategory_Click(object? sender, RoutedEventArgs e) => ToggleCategory(MediaCategory.Audio);
    private void SelectPdfCategory_Click(object? sender, RoutedEventArgs e) => ToggleCategory(MediaCategory.Pdf);

    private void ToggleCategory(MediaCategory category)
    {
        if (_state.ActiveFormatCategory == category && _state.IsFormatDrawerExpanded)
        {
            _state.IsFormatDrawerExpanded = false;
            FormatDrawerBorder.IsVisible = false;
        }
        else
        {
            _state.ActiveFormatCategory = category;
            _state.IsFormatDrawerExpanded = true;
            FormatDrawerBorder.IsVisible = true;
            ImagesDeckPanel.IsVisible = category == MediaCategory.Images;
            VideoDeckPanel.IsVisible = category == MediaCategory.Video;
            AudioDeckPanel.IsVisible = category == MediaCategory.Audio;
            PdfDeckPanel.IsVisible = category == MediaCategory.Pdf;
        }
        UpdateTileStyles();
    }

    private void UpdateTileStyles()
    {
        var accentBrush = SolidColorBrush.Parse(_state.AccentColorHex);
        var defaultBorder = SolidColorBrush.Parse("#2D2D32");
        bool exp = _state.IsFormatDrawerExpanded;

        ImagesTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Images) ? accentBrush : defaultBorder;
        ImagesChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Images) ? "▲" : "▼";
        ImagesChevron.Foreground = (exp && _state.ActiveFormatCategory == MediaCategory.Images) ? SolidColorBrush.Parse(_state.AccentColorHex) : SolidColorBrush.Parse("#55556A");

        VideoTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Video) ? accentBrush : defaultBorder;
        VideoChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Video) ? "▲" : "▼";
        VideoChevron.Foreground = (exp && _state.ActiveFormatCategory == MediaCategory.Video) ? SolidColorBrush.Parse(_state.AccentColorHex) : SolidColorBrush.Parse("#55556A");

        AudioTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Audio) ? accentBrush : defaultBorder;
        AudioChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Audio) ? "▲" : "▼";
        AudioChevron.Foreground = (exp && _state.ActiveFormatCategory == MediaCategory.Audio) ? SolidColorBrush.Parse(_state.AccentColorHex) : SolidColorBrush.Parse("#55556A");

        PdfTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Pdf) ? accentBrush : defaultBorder;
        PdfChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Pdf) ? "▲" : "▼";
        PdfChevron.Foreground = (exp && _state.ActiveFormatCategory == MediaCategory.Pdf) ? SolidColorBrush.Parse(_state.AccentColorHex) : SolidColorBrush.Parse("#55556A");
    }

    // ── Presets ──
    private void PresetOff_Click(object? sender, RoutedEventArgs e) { _state.TargetSizeMode = TargetSizeMode.Off; QuickDropLimitPill.Text = "Manual Quality"; UpdatePresetButtonStyles(PresetOffBtn); }
    private void Preset25_Click(object? sender, RoutedEventArgs e) { _state.TargetSizeMode = TargetSizeMode.Discord25; QuickDropLimitPill.Text = "25 MB Limit"; UpdatePresetButtonStyles(Preset25Btn); }
    private void Preset10_Click(object? sender, RoutedEventArgs e) { _state.TargetSizeMode = TargetSizeMode.Email10; QuickDropLimitPill.Text = "10 MB Limit"; UpdatePresetButtonStyles(Preset10Btn); }
    private void Preset50_Click(object? sender, RoutedEventArgs e) { _state.TargetSizeMode = TargetSizeMode.Discord50; QuickDropLimitPill.Text = "50 MB Limit"; UpdatePresetButtonStyles(Preset50Btn); }

    private void UpdatePresetButtonStyles(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(_state.AccentColorHex);
        var inactiveFg = SolidColorBrush.Parse("#A0A0B0");

        foreach (var btn in new[] { PresetOffBtn, Preset25Btn, Preset10Btn, Preset50Btn })
        {
            btn.Background = inactive;
            btn.Foreground = inactiveFg;
            btn.BorderBrush = SolidColorBrush.Parse("#2D2D32");
        }
        activeBtn.Background = activeBg;
        activeBtn.Foreground = Brushes.Black;
        activeBtn.BorderBrush = Brushes.Transparent;
    }

    // ── Resolution Buttons ──
    private void ImgScale100_Click(object? sender, RoutedEventArgs e) { _state.ImageResolutionScale = 1.0; UpdateImgScaleButtons(ImgScale100Btn); }
    private void ImgScale75_Click(object? sender, RoutedEventArgs e) { _state.ImageResolutionScale = 0.75; UpdateImgScaleButtons(ImgScale75Btn); }
    private void ImgScale50_Click(object? sender, RoutedEventArgs e) { _state.ImageResolutionScale = 0.50; UpdateImgScaleButtons(ImgScale50Btn); }
    private void ImgScale25_Click(object? sender, RoutedEventArgs e) { _state.ImageResolutionScale = 0.25; UpdateImgScaleButtons(ImgScale25Btn); }

    private void UpdateImgScaleButtons(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(_state.AccentColorHex);
        var inactiveFg = SolidColorBrush.Parse("#A0A0B0");

        foreach (var btn in new[] { ImgScale100Btn, ImgScale75Btn, ImgScale50Btn, ImgScale25Btn })
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

    private void VidScale100_Click(object? sender, RoutedEventArgs e) { _state.VideoResolutionScale = 1.0; UpdateVidScaleButtons(VidScale100Btn); }
    private void VidScale75_Click(object? sender, RoutedEventArgs e) { _state.VideoResolutionScale = 0.75; UpdateVidScaleButtons(VidScale75Btn); }
    private void VidScale50_Click(object? sender, RoutedEventArgs e) { _state.VideoResolutionScale = 0.50; UpdateVidScaleButtons(VidScale50Btn); }
    private void VidScale25_Click(object? sender, RoutedEventArgs e) { _state.VideoResolutionScale = 0.25; UpdateVidScaleButtons(VidScale25Btn); }

    private void UpdateVidScaleButtons(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(_state.AccentColorHex);
        var inactiveFg = SolidColorBrush.Parse("#A0A0B0");

        foreach (var btn in new[] { VidScale100Btn, VidScale75Btn, VidScale50Btn, VidScale25Btn })
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

    private void PdfDpi72_Click(object? sender, RoutedEventArgs e) { _state.PdfDpi = 72; UpdatePdfDpiButtons(PdfDpi72Btn); }
    private void PdfDpi150_Click(object? sender, RoutedEventArgs e) { _state.PdfDpi = 150; UpdatePdfDpiButtons(PdfDpi150Btn); }
    private void PdfDpi200_Click(object? sender, RoutedEventArgs e) { _state.PdfDpi = 200; UpdatePdfDpiButtons(PdfDpi200Btn); }
    private void PdfDpi300_Click(object? sender, RoutedEventArgs e) { _state.PdfDpi = 300; UpdatePdfDpiButtons(PdfDpi300Btn); }

    private void UpdatePdfDpiButtons(Button activeBtn)
    {
        var inactive = SolidColorBrush.Parse("#28282C");
        var activeBg = SolidColorBrush.Parse(_state.AccentColorHex);
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

    // ── Drag & Drop ──
    private void OnDragOver(object? sender, DragEventArgs e) => e.DragEffects = e.Data.Contains(DataFormats.Files) ? DragDropEffects.Copy : DragDropEffects.None;

    private async void OnQuickDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files is { Count: > 0 }) await _state.ProcessDroppedFilesImmediatelyAsync(files);
    }

    private void OnStagedDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files is { Count: > 0 }) _state.AddFilesToStagedQueue(files);
    }

    private void CustomizeItem_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is StagedQueueItem item) new QueueItemSettingsDialog(item).ShowDialog(this);
    }

    private void DeleteItem_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is Guid id) _state.RemoveFromStagedQueue(id);
    }

    private void ClearQueue_Click(object? sender, RoutedEventArgs e) => _state.ClearStagedQueue();
    private async void SqueezeAll_Click(object? sender, RoutedEventArgs e) => await _state.ProcessStagedQueueAsync();
    private void CancelSingleJob_Click(object? sender, RoutedEventArgs e) { if (sender is Button btn && btn.Tag is Guid id) _state.CancelJob(id); }
    private void CancelAllJobs_Click(object? sender, RoutedEventArgs e) => _state.CancelAllJobs();

    private void OpenFolder_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string path && File.Exists(path))
        {
            try { Process.Start(new ProcessStartInfo { FileName = "explorer.exe", Arguments = $"/select,\"{path}\"", UseShellExecute = true }); }
            catch { /* Wine/CrossOver may not support explorer.exe */ }
        }
    }

    // ── macOS-Style Theme Color Swatches ──
    private void ThemeCyan_Click(object? sender, RoutedEventArgs e) => ApplyTheme("#00D2FF", "Cyan", ColorBallCyan);
    private void ThemeEmerald_Click(object? sender, RoutedEventArgs e) => ApplyTheme("#00E676", "Emerald", ColorBallEmerald);
    private void ThemePurple_Click(object? sender, RoutedEventArgs e) => ApplyTheme("#A855F7", "Purple", ColorBallPurple);
    private void ThemeSunset_Click(object? sender, RoutedEventArgs e) => ApplyTheme("#FF9500", "Amber", ColorBallSunset);
    private void ThemeRose_Click(object? sender, RoutedEventArgs e) => ApplyTheme("#FF2D55", "Rose", ColorBallRose);
    private void ThemeBlue_Click(object? sender, RoutedEventArgs e) => ApplyTheme("#007AFF", "Blue", ColorBallBlue);

    private int _customColorIndex = 0;
    private readonly string[] _customColors = { "#FF2D55", "#5856D6", "#00C7BE", "#30D158", "#FF9500" };

    private void ThemeCustom_Click(object? sender, RoutedEventArgs e)
    {
        string color = _customColors[_customColorIndex % _customColors.Length];
        _customColorIndex++;
        ApplyTheme(color, $"#{color.TrimStart('#')}", ColorBallCustom);
    }

    private void ApplyTheme(string hex, string label, Button activeBall)
    {
        _state.AccentColorHex = hex;
        ThemeColorLabel.Text = label;
        ThemeColorLabel.Foreground = SolidColorBrush.Parse(hex);
        SavedStatsText.Foreground = SolidColorBrush.Parse(hex);
        ImgQualityLabel.Foreground = SolidColorBrush.Parse(hex);
        VidQualityLabel.Foreground = SolidColorBrush.Parse(hex);
        LifetimeSavedText.Foreground = SolidColorBrush.Parse(hex);
        UpdateTileStyles();

        // macOS-style: 22px default, 28px + white ring for selected
        var balls = new[] { ColorBallCyan, ColorBallEmerald, ColorBallPurple, ColorBallSunset, ColorBallRose, ColorBallBlue, ColorBallCustom };
        foreach (var b in balls)
        {
            b.BorderBrush = Brushes.Transparent;
            b.BorderThickness = new Thickness(0);
            b.Width = 22;
            b.Height = 22;
            b.CornerRadius = new CornerRadius(11);
        }

        // Selected swatch: slightly larger with white ring + subtle shadow
        activeBall.BorderBrush = Brushes.White;
        activeBall.BorderThickness = new Thickness(2);
        activeBall.Width = 28;
        activeBall.Height = 28;
        activeBall.CornerRadius = new CornerRadius(14);
    }

    // ── Watched Folders ──
    private async void AddWatchedFolder_Click(object? sender, RoutedEventArgs e)
    {
        var topLevel = TopLevel.GetTopLevel(this);
        if (topLevel != null)
        {
            var folders = await topLevel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions { Title = "Select Folder to Auto-Squeeze" });
            if (folders.Count > 0)
            {
                string path = folders[0].Path.LocalPath;
                if (!_state.WatchedFolders.Contains(path))
                {
                    _state.WatchedFolders.Add(path);
                    FolderWatchService.Shared.StartWatching(path);
                    EmptyWatchedHint.IsVisible = _state.WatchedFolders.Count == 0;
                }
            }
        }
    }

    private void RemoveWatchedFolder_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string path)
        {
            _state.WatchedFolders.Remove(path);
            FolderWatchService.Shared.StopWatching(path);
            EmptyWatchedHint.IsVisible = _state.WatchedFolders.Count == 0;
        }
    }

    private void ResetStats_Click(object? sender, RoutedEventArgs e) => _state.ResetStats();

    private void ToggleFloatingBall_Click(object? sender, RoutedEventArgs e)
    {
        if (_floatingBasket == null || !_floatingBasket.IsVisible)
        {
            _floatingBasket = new FloatingBasketWindow();
            _floatingBasket.Show();
        }
        else
        {
            _floatingBasket.Hide();
        }
    }
}
