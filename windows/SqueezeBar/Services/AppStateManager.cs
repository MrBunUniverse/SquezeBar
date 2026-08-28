using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using SqueezeBar.Models;

namespace SqueezeBar.Services;

public class AppStateManager : INotifyPropertyChanged
{
    private static readonly Lazy<AppStateManager> _instance = new(() => new AppStateManager());
    public static AppStateManager Shared => _instance.Value;

    public CompressionConfiguration BaseConfig { get; } = new();

    public ObservableCollection<StagedQueueItem> StagedQueue { get; } = new();
    public ObservableCollection<CompressionJob> ActiveJobs { get; } = new();
    public ObservableCollection<CompressionResult> History { get; } = new();

    private long _totalBytesSaved;
    public long TotalBytesSaved
    {
        get => _totalBytesSaved;
        set { _totalBytesSaved = value; OnPropertyChanged(); OnPropertyChanged(nameof(FormattedTotalSaved)); }
    }

    private int _totalFilesSqueezed;
    public int TotalFilesSqueezed
    {
        get => _totalFilesSqueezed;
        set { _totalFilesSqueezed = value; OnPropertyChanged(); }
    }

    private bool _isProcessing;
    public bool IsProcessing
    {
        get => _isProcessing;
        set { _isProcessing = value; OnPropertyChanged(); }
    }

    public string FormattedTotalSaved
    {
        get
        {
            if (TotalBytesSaved < 1024) return $"{TotalBytesSaved} B";
            if (TotalBytesSaved < 1024 * 1024) return $"{TotalBytesSaved / 1024.0:F1} KB";
            if (TotalBytesSaved < 1024 * 1024 * 1024) return $"{TotalBytesSaved / (1024.0 * 1024):F1} MB";
            return $"{TotalBytesSaved / (1024.0 * 1024 * 1024):F2} GB";
        }
    }

    public void AddFilesToQueue(IEnumerable<string> paths)
    {
        var resolved = MediaCompressionEngine.Shared.GatherMediaFiles(paths);
        foreach (var path in resolved)
        {
            var type = MediaCompressionEngine.Shared.ClassifyFile(path);
            if (type == MediaType.Unsupported) continue;

            long size = new FileInfo(path).Length;
            var item = new StagedQueueItem(path, size, type, BaseConfig);
            StagedQueue.Add(item);
        }
        OnPropertyChanged(nameof(StagedQueueCountText));
    }

    public void RemoveFromQueue(Guid id)
    {
        var item = StagedQueue.FirstOrDefault(x => x.Id == id);
        if (item != null)
        {
            StagedQueue.Remove(item);
            OnPropertyChanged(nameof(StagedQueueCountText));
        }
    }

    public void ClearQueue()
    {
        StagedQueue.Clear();
        OnPropertyChanged(nameof(StagedQueueCountText));
    }

    public string StagedQueueCountText => $"Staged Queue ({StagedQueue.Count})";

    public async Task ProcessStagedQueueAsync()
    {
        if (StagedQueue.Count == 0 || IsProcessing) return;

        IsProcessing = true;
        var itemsToProcess = StagedQueue.ToList();
        StagedQueue.Clear();
        OnPropertyChanged(nameof(StagedQueueCountText));

        foreach (var item in itemsToProcess)
        {
            var job = new CompressionJob
            {
                FilePath = item.FilePath,
                MediaType = item.MediaType,
                StatusText = "Compressing..."
            };
            ActiveJobs.Insert(0, job);

            var itemConfig = item.BuildConfiguration(BaseConfig);
            var progress = new Progress<double>(p => job.Progress = p);

            var result = await Task.Run(() => MediaCompressionEngine.Shared.CompressFileAsync(item.FilePath, itemConfig, progress));

            job.IsCompleted = true;
            if (result != null)
            {
                job.StatusText = "Done";
                History.Insert(0, result);
                TotalBytesSaved += result.BytesSaved;
                TotalFilesSqueezed++;
            }
            else
            {
                job.StatusText = "Failed";
            }
        }

        IsProcessing = false;
    }

    public async Task ProcessDroppedFilesImmediatelyAsync(IEnumerable<string> paths)
    {
        var resolved = MediaCompressionEngine.Shared.GatherMediaFiles(paths);
        if (resolved.Count == 0) return;

        IsProcessing = true;
        foreach (var path in resolved)
        {
            var type = MediaCompressionEngine.Shared.ClassifyFile(path);
            var job = new CompressionJob
            {
                FilePath = path,
                MediaType = type,
                StatusText = "Compressing..."
            };
            ActiveJobs.Insert(0, job);

            var progress = new Progress<double>(p => job.Progress = p);
            var result = await Task.Run(() => MediaCompressionEngine.Shared.CompressFileAsync(path, BaseConfig, progress));

            job.IsCompleted = true;
            if (result != null)
            {
                job.StatusText = "Done";
                History.Insert(0, result);
                TotalBytesSaved += result.BytesSaved;
                TotalFilesSqueezed++;
            }
            else
            {
                job.StatusText = "Failed";
            }
        }
        IsProcessing = false;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    protected void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
