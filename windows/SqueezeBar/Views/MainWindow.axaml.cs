using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using SqueezeBar.Models;
using SqueezeBar.Services;

namespace SqueezeBar.Views;

public partial class MainWindow : Window
{
    private FloatingBasketWindow? _floatingBasket;

    public MainWindow()
    {
        InitializeComponent();

        var state = AppStateManager.Shared;
        StagedQueueItemsList.ItemsSource = state.StagedQueue;
        HistoryItemsList.ItemsSource = state.History;

        state.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(state.FormattedTotalSaved))
            {
                SavedStatsText.Text = $"{state.FormattedTotalSaved} Saved";
            }
            else if (e.PropertyName == nameof(state.StagedQueueCountText))
            {
                QueueHeaderTitle.Text = state.StagedQueueCountText;
                EmptyQueueHint.IsVisible = state.StagedQueue.Count == 0;
            }
            else if (e.PropertyName == nameof(state.IsProcessing))
            {
                StatusText.Text = state.IsProcessing ? "Compressing files..." : "Ready • Drop files to squeeze";
            }
        };

        // Quick Squeeze Drop Zone
        QuickDropBorder.AddHandler(DragDrop.DropEvent, OnQuickDrop);
        QuickDropBorder.AddHandler(DragDrop.DragOverEvent, OnDragOver);

        // Staged Queue Drop Zone
        StagedQueueBorder.AddHandler(DragDrop.DropEvent, OnStagedDrop);
        StagedQueueBorder.AddHandler(DragDrop.DragOverEvent, OnDragOver);

        EmptyQueueHint.IsVisible = state.StagedQueue.Count == 0;
    }

    private void OnDragOver(object? sender, DragEventArgs e)
    {
        if (e.Data.Contains(DataFormats.Files))
        {
            e.DragEffects = DragDropEffects.Copy;
        }
        else
        {
            e.DragEffects = DragDropEffects.None;
        }
    }

    private async void OnQuickDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files != null && files.Count > 0)
        {
            await AppStateManager.Shared.ProcessDroppedFilesImmediatelyAsync(files);
        }
    }

    private void OnStagedDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files != null && files.Count > 0)
        {
            AppStateManager.Shared.AddFilesToQueue(files);
        }
    }

    private void SettingsButton_Click(object? sender, RoutedEventArgs e)
    {
        var dialog = new SettingsDialog();
        dialog.ShowDialog(this);
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
            AppStateManager.Shared.RemoveFromQueue(id);
        }
    }

    private void ClearQueue_Click(object? sender, RoutedEventArgs e)
    {
        AppStateManager.Shared.ClearQueue();
    }

    private async void SqueezeAll_Click(object? sender, RoutedEventArgs e)
    {
        await AppStateManager.Shared.ProcessStagedQueueAsync();
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
