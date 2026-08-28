using System;
using System.Collections.Generic;
using System.IO;
using SqueezeBar.Models;

namespace SqueezeBar.Services;

public class FolderWatchService
{
    private static readonly Lazy<FolderWatchService> _instance = new(() => new FolderWatchService());
    public static FolderWatchService Shared => _instance.Value;

    private readonly Dictionary<string, FileSystemWatcher> _watchers = new(StringComparer.OrdinalIgnoreCase);

    public void StartWatching(string folderPath)
    {
        if (string.IsNullOrWhiteSpace(folderPath) || !Directory.Exists(folderPath) || _watchers.ContainsKey(folderPath))
            return;

        try
        {
            var watcher = new FileSystemWatcher(folderPath)
            {
                NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.Size,
                IncludeSubdirectories = false,
                EnableRaisingEvents = true
            };

            watcher.Created += (s, e) =>
            {
                if (File.Exists(e.FullPath))
                {
                    // Delay slightly to ensure file has finished writing
                    System.Threading.Tasks.Task.Delay(500).ContinueWith(_ =>
                    {
                        Avalonia.Threading.Dispatcher.UIThread.Post(() =>
                        {
                            AppState.Shared.AddFilesToStagedQueue(new[] { e.FullPath });
                        });
                    });
                }
            };

            _watchers[folderPath] = watcher;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[FolderWatchService] Failed to watch {folderPath}: {ex.Message}");
        }
    }

    public void StopWatching(string folderPath)
    {
        if (_watchers.TryGetValue(folderPath, out var watcher))
        {
            watcher.EnableRaisingEvents = false;
            watcher.Dispose();
            _watchers.Remove(folderPath);
        }
    }

    public void SyncWatchers(IEnumerable<string> paths)
    {
        var currentPaths = new HashSet<string>(paths, StringComparer.OrdinalIgnoreCase);
        var existingPaths = _watchers.Keys.ToList();

        foreach (var p in existingPaths)
        {
            if (!currentPaths.Contains(p))
            {
                StopWatching(p);
            }
        }

        foreach (var p in currentPaths)
        {
            if (!_watchers.ContainsKey(p))
            {
                StartWatching(p);
            }
        }
    }
}
