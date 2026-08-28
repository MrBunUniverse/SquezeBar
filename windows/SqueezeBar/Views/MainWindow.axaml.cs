using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
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

    public MainWindow()
    {
        InitializeComponent();

        StagedQueueItemsList.ItemsSource = _state.StagedQueue;
        HistoryItemsList.ItemsSource = _state.History;
        ActiveJobsList.ItemsSource = _state.ActiveJobs;
        WatchedFoldersList.ItemsSource = _state.WatchedFolders;

        // Reactive property change subscriptions
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
                FooterStatusText.Text = _state.IsProcessing ? "Optimizing media files..." : "Ready • Drop media to squeeze";
            }
            else if (e.PropertyName == nameof(_state.ImageSummaryText))
            {
                ImagesTileSummary.Text = _state.ImageSummaryText;
            }
            else if (e.PropertyName == nameof(_state.VideoSummaryText))
            {
                VideoTileSummary.Text = _state.VideoSummaryText;
            }
            else if (e.PropertyName == nameof(_state.AudioSummaryText))
            {
                AudioTileSummary.Text = _state.AudioSummaryText;
            }
            else if (e.PropertyName == nameof(_state.PdfSummaryText))
            {
                PdfTileSummary.Text = _state.PdfSummaryText;
            }
        };

        // Quality Sliders
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

        PdfGrayscaleCheck.IsCheckedChanged += (s, e) =>
        {
            _state.PdfGrayscale = PdfGrayscaleCheck.IsChecked ?? false;
        };

        // General settings
        SettingsSuffixBox.PropertyChanged += (s, e) =>
        {
            if (e.Property.Name == nameof(TextBox.Text))
            {
                _state.OutputSuffix = SettingsSuffixBox.Text?.Trim() ?? "_squeezed";
            }
        };

        ReplaceOriginalCheck.IsCheckedChanged += (s, e) =>
        {
            _state.ReplaceOriginal = ReplaceOriginalCheck.IsChecked ?? false;
        };

        StripMetadataCheck.IsCheckedChanged += (s, e) =>
        {
            _state.StripMetadata = StripMetadataCheck.IsChecked ?? true;
        };

        // Drag & Drop
        QuickDropBorder.AddHandler(DragDrop.DropEvent, OnQuickDrop);
        QuickDropBorder.AddHandler(DragDrop.DragOverEvent, OnDragOver);

        StagedQueueBorder.AddHandler(DragDrop.DropEvent, OnStagedDrop);
        StagedQueueBorder.AddHandler(DragDrop.DragOverEvent, OnDragOver);

        EmptyQueueHint.IsVisible = _state.StagedQueue.Count == 0;
    }

    // Tab Navigation
    private void ActivityTab_Click(object? sender, RoutedEventArgs e)
    {
        _state.SelectedTab = PopoverTab.Activity;
        ActivityTabPanel.IsVisible = true;
        SettingsTabPanel.IsVisible = false;

        ActivityTabBtn.Background = SolidColorBrush.Parse(_state.AccentColorHex);
        ActivityTabBtn.Foreground = Brushes.Black;
        SettingsTabBtn.Background = Brushes.Transparent;
        SettingsTabBtn.Foreground = SolidColorBrush.Parse("#8E9297");
    }

    private void SettingsTab_Click(object? sender, RoutedEventArgs e)
    {
        _state.SelectedTab = PopoverTab.Settings;
        ActivityTabPanel.IsVisible = false;
        SettingsTabPanel.IsVisible = true;

        SettingsTabBtn.Background = SolidColorBrush.Parse(_state.AccentColorHex);
        SettingsTabBtn.Foreground = Brushes.Black;
        ActivityTabBtn.Background = Brushes.Transparent;
        ActivityTabBtn.Foreground = SolidColorBrush.Parse("#8E9297");
    }

    // Category Tile Selection
    private void SelectImagesCategory_Click(object? sender, RoutedEventArgs e)
    {
        if (_state.ActiveFormatCategory == MediaCategory.Images && _state.IsFormatDrawerExpanded)
        {
            _state.IsFormatDrawerExpanded = false;
            FormatDrawerBorder.IsVisible = false;
        }
        else
        {
            _state.ActiveFormatCategory = MediaCategory.Images;
            _state.IsFormatDrawerExpanded = true;
            FormatDrawerBorder.IsVisible = true;
            ShowCategoryDeck(MediaCategory.Images);
        }
        UpdateTileStyles();
    }

    private void SelectVideoCategory_Click(object? sender, RoutedEventArgs e)
    {
        if (_state.ActiveFormatCategory == MediaCategory.Video && _state.IsFormatDrawerExpanded)
        {
            _state.IsFormatDrawerExpanded = false;
            FormatDrawerBorder.IsVisible = false;
        }
        else
        {
            _state.ActiveFormatCategory = MediaCategory.Video;
            _state.IsFormatDrawerExpanded = true;
            FormatDrawerBorder.IsVisible = true;
            ShowCategoryDeck(MediaCategory.Video);
        }
        UpdateTileStyles();
    }

    private void SelectAudioCategory_Click(object? sender, RoutedEventArgs e)
    {
        if (_state.ActiveFormatCategory == MediaCategory.Audio && _state.IsFormatDrawerExpanded)
        {
            _state.IsFormatDrawerExpanded = false;
            FormatDrawerBorder.IsVisible = false;
        }
        else
        {
            _state.ActiveFormatCategory = MediaCategory.Audio;
            _state.IsFormatDrawerExpanded = true;
            FormatDrawerBorder.IsVisible = true;
            ShowCategoryDeck(MediaCategory.Audio);
        }
        UpdateTileStyles();
    }

    private void SelectPdfCategory_Click(object? sender, RoutedEventArgs e)
    {
        if (_state.ActiveFormatCategory == MediaCategory.Pdf && _state.IsFormatDrawerExpanded)
        {
            _state.IsFormatDrawerExpanded = false;
            FormatDrawerBorder.IsVisible = false;
        }
        else
        {
            _state.ActiveFormatCategory = MediaCategory.Pdf;
            _state.IsFormatDrawerExpanded = true;
            FormatDrawerBorder.IsVisible = true;
            ShowCategoryDeck(MediaCategory.Pdf);
        }
        UpdateTileStyles();
    }

    private void ShowCategoryDeck(MediaCategory category)
    {
        ImagesDeckPanel.IsVisible = category == MediaCategory.Images;
        VideoDeckPanel.IsVisible = category == MediaCategory.Video;
        AudioDeckPanel.IsVisible = category == MediaCategory.Audio;
        PdfDeckPanel.IsVisible = category == MediaCategory.Pdf;
    }

    private void UpdateTileStyles()
    {
        var activeBrush = SolidColorBrush.Parse(_state.AccentColorHex);
        var inactiveBrush = SolidColorBrush.Parse("#262932");

        bool exp = _state.IsFormatDrawerExpanded;

        ImagesTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Images) ? activeBrush : inactiveBrush;
        ImagesChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Images) ? "▲" : "▼";

        VideoTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Video) ? activeBrush : inactiveBrush;
        VideoChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Video) ? "▲" : "▼";

        AudioTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Audio) ? activeBrush : inactiveBrush;
        AudioChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Audio) ? "▲" : "▼";

        PdfTileBorder.BorderBrush = (exp && _state.ActiveFormatCategory == MediaCategory.Pdf) ? activeBrush : inactiveBrush;
        PdfChevron.Text = (exp && _state.ActiveFormatCategory == MediaCategory.Pdf) ? "▲" : "▼";
    }

    // Presets
    private void PresetOff_Click(object? sender, RoutedEventArgs e)
    {
        _state.TargetSizeMode = TargetSizeMode.Off;
        QuickDropLimitPill.Text = "Limit: Off";
        UpdatePresetButtonStyles(PresetOffBtn);
    }

    private void Preset25_Click(object? sender, RoutedEventArgs e)
    {
        _state.TargetSizeMode = TargetSizeMode.Discord25;
        QuickDropLimitPill.Text = "Discord: 25MB";
        UpdatePresetButtonStyles(Preset25Btn);
    }

    private void Preset10_Click(object? sender, RoutedEventArgs e)
    {
        _state.TargetSizeMode = TargetSizeMode.Email10;
        QuickDropLimitPill.Text = "Email: 10MB";
        UpdatePresetButtonStyles(Preset10Btn);
    }

    private void Preset50_Click(object? sender, RoutedEventArgs e)
    {
        _state.TargetSizeMode = TargetSizeMode.Discord50;
        QuickDropLimitPill.Text = "Nitro: 50MB";
        UpdatePresetButtonStyles(Preset50Btn);
    }

    private void UpdatePresetButtonStyles(Button activeBtn)
    {
        var inactiveBrush = SolidColorBrush.Parse("#20242E");
        var activeBrush = SolidColorBrush.Parse(_state.AccentColorHex);

        PresetOffBtn.Background = inactiveBrush; PresetOffBtn.Foreground = SolidColorBrush.Parse("#CCCCCC");
        Preset25Btn.Background = inactiveBrush; Preset25Btn.Foreground = SolidColorBrush.Parse("#CCCCCC");
        Preset10Btn.Background = inactiveBrush; Preset10Btn.Foreground = SolidColorBrush.Parse("#CCCCCC");
        Preset50Btn.Background = inactiveBrush; Preset50Btn.Foreground = SolidColorBrush.Parse("#CCCCCC");

        activeBtn.Background = activeBrush;
        activeBtn.Foreground = Brushes.Black;
    }

    // Resolution Buttons
    private void ImgScale100_Click(object? sender, RoutedEventArgs e) => _state.ImageResolutionScale = 1.0;
    private void ImgScale75_Click(object? sender, RoutedEventArgs e) => _state.ImageResolutionScale = 0.75;
    private void ImgScale50_Click(object? sender, RoutedEventArgs e) => _state.ImageResolutionScale = 0.50;
    private void ImgScale25_Click(object? sender, RoutedEventArgs e) => _state.ImageResolutionScale = 0.25;

    private void VidScale100_Click(object? sender, RoutedEventArgs e) => _state.VideoResolutionScale = 1.0;
    private void VidScale75_Click(object? sender, RoutedEventArgs e) => _state.VideoResolutionScale = 0.75;
    private void VidScale50_Click(object? sender, RoutedEventArgs e) => _state.VideoResolutionScale = 0.50;
    private void VidScale25_Click(object? sender, RoutedEventArgs e) => _state.VideoResolutionScale = 0.25;

    private void PdfDpi72_Click(object? sender, RoutedEventArgs e) => _state.PdfDpi = 72;
    private void PdfDpi150_Click(object? sender, RoutedEventArgs e) => _state.PdfDpi = 150;
    private void PdfDpi200_Click(object? sender, RoutedEventArgs e) => _state.PdfDpi = 200;
    private void PdfDpi300_Click(object? sender, RoutedEventArgs e) => _state.PdfDpi = 300;

    // Drag & Drop
    private void OnDragOver(object? sender, DragEventArgs e)
    {
        e.DragEffects = e.Data.Contains(DataFormats.Files) ? DragDropEffects.Copy : DragDropEffects.None;
    }

    private async void OnQuickDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files != null && files.Count > 0)
        {
            await _state.ProcessDroppedFilesImmediatelyAsync(files);
        }
    }

    private void OnStagedDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files != null && files.Count > 0)
        {
            _state.AddFilesToStagedQueue(files);
        }
    }

    private void CustomizeItem_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is StagedQueueItem item)
        {
            var dialog = new QueueItemSettingsDialog(item);
            dialog.ShowDialog(this);
        }
    }

    private void DeleteItem_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is Guid id)
        {
            _state.RemoveFromStagedQueue(id);
        }
    }

    private void ClearQueue_Click(object? sender, RoutedEventArgs e)
    {
        _state.ClearStagedQueue();
    }

    private async void SqueezeAll_Click(object? sender, RoutedEventArgs e)
    {
        await _state.ProcessStagedQueueAsync();
    }

    private void CancelSingleJob_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is Guid id)
        {
            _state.CancelJob(id);
        }
    }

    private void CancelAllJobs_Click(object? sender, RoutedEventArgs e)
    {
        _state.CancelAllJobs();
    }

    private void OpenFolder_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string path && File.Exists(path))
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = $"/select,\"{path}\"",
                    UseShellExecute = true
                });
            }
            catch { }
        }
    }

    // Theme Color Actions
    private void ThemeCyan_Click(object? sender, RoutedEventArgs e) => ApplyThemeColor("#00D2FF");
    private void ThemeEmerald_Click(object? sender, RoutedEventArgs e) => ApplyThemeColor("#00E676");
    private void ThemePurple_Click(object? sender, RoutedEventArgs e) => ApplyThemeColor("#A855F7");
    private void ThemeSunset_Click(object? sender, RoutedEventArgs e) => ApplyThemeColor("#FF6B00");
    private void ThemeBlue_Click(object? sender, RoutedEventArgs e) => ApplyThemeColor("#007AFF");

    private void ApplyThemeColor(string hex)
    {
        _state.AccentColorHex = hex;
        QuickDropBorder.BorderBrush = SolidColorBrush.Parse(hex);
        SavedStatsText.Foreground = SolidColorBrush.Parse(hex);
        UpdateTileStyles();
        if (_state.SelectedTab == PopoverTab.Activity)
        {
            ActivityTabBtn.Background = SolidColorBrush.Parse(hex);
        }
        else
        {
            SettingsTabBtn.Background = SolidColorBrush.Parse(hex);
        }
    }

    // Watched Folders
    private async void AddWatchedFolder_Click(object? sender, RoutedEventArgs e)
    {
        var topLevel = TopLevel.GetTopLevel(this);
        if (topLevel != null)
        {
            var folders = await topLevel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                Title = "Select Folder to Auto-Squeeze"
            });

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

    private void ResetStats_Click(object? sender, RoutedEventArgs e)
    {
        _state.ResetStats();
    }

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
