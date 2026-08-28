using System.Linq;
using Avalonia.Controls;
using Avalonia.Input;
using SqueezeBar.Services;

namespace SqueezeBar.Views;

public partial class FloatingBasketWindow : Window
{
    public FloatingBasketWindow()
    {
        InitializeComponent();

        AddHandler(DragDrop.DropEvent, OnDrop);
        AddHandler(DragDrop.DragOverEvent, OnDragOver);

        PointerPressed += (s, e) =>
        {
            if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
            {
                BeginMoveDrag(e);
            }
        };
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

    private async void OnDrop(object? sender, DragEventArgs e)
    {
        var files = e.Data.GetFiles()?.Select(f => f.Path.LocalPath).ToList();
        if (files != null && files.Count > 0)
        {
            await AppStateManager.Shared.ProcessDroppedFilesImmediatelyAsync(files);
        }
    }
}
