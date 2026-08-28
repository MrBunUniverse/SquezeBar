using System;
using System.IO;
using System.Threading.Tasks;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;
using SqueezeBar.Models;

namespace SqueezeBar.Services;

public static class ImageCompressor
{
    public static async Task<CompressionResult?> CompressImageAsync(
        string inputPath,
        CompressionConfiguration config,
        IProgress<double>? progress = null)
    {
        try
        {
            if (!File.Exists(inputPath)) return null;

            progress?.Report(0.1);
            var fileInfo = new FileInfo(inputPath);
            long originalSize = fileInfo.Length;

            using var image = await Image.LoadAsync(inputPath);
            progress?.Report(0.3);

            // 1. Resolution Scaling
            if (config.ImageResolutionScale < 0.99)
            {
                int newWidth = Math.Max(1, (int)(image.Width * config.ImageResolutionScale));
                int newHeight = Math.Max(1, (int)(image.Height * config.ImageResolutionScale));
                image.Mutate(x => x.Resize(newWidth, newHeight, KnownResamplers.Lanczos3));
            }

            // 2. Strip EXIF / Metadata
            if (config.StripMetadata)
            {
                image.Metadata.ExifProfile = null;
                image.Metadata.IptcProfile = null;
                image.Metadata.XmpProfile = null;
            }

            progress?.Report(0.6);

            // 3. Determine Output Format and Extension
            string dir = Path.GetDirectoryName(inputPath) ?? "";
            string nameWithoutExt = Path.GetFileNameWithoutExtension(inputPath);
            string origExt = Path.GetExtension(inputPath).ToLowerInvariant();

            string targetExt = config.ImageFormatPolicy switch
            {
                ImageFormatPolicy.ModernWebP => ".webp",
                ImageFormatPolicy.WebJPEG => ".jpg",
                ImageFormatPolicy.PreserveOriginal => origExt,
                _ => origExt
            };

            string outputPath = Path.Combine(dir, $"{nameWithoutExt}{config.OutputSuffix}{targetExt}");
            int counter = 1;
            while (File.Exists(outputPath))
            {
                outputPath = Path.Combine(dir, $"{nameWithoutExt}{config.OutputSuffix}_{counter}{targetExt}");
                counter++;
            }

            // 4. Encode and Save with Quality Setting
            int quality = Math.Clamp((int)(config.ImageQuality * 100), 5, 100);

            if (targetExt == ".webp")
            {
                var encoder = new WebpEncoder { Quality = quality };
                await image.SaveAsWebpAsync(outputPath, encoder);
            }
            else if (targetExt == ".png")
            {
                var encoder = new PngEncoder { CompressionLevel = PngCompressionLevel.BestCompression };
                await image.SaveAsPngAsync(outputPath, encoder);
            }
            else
            {
                var encoder = new JpegEncoder { Quality = quality };
                await image.SaveAsJpegAsync(outputPath, encoder);
            }

            progress?.Report(1.0);

            var outFile = new FileInfo(outputPath);
            return new CompressionResult
            {
                OriginalPath = inputPath,
                OutputPath = outputPath,
                OriginalSize = originalSize,
                CompressedSize = outFile.Length,
                MediaType = MediaType.Image
            };
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[ImageCompressor] Error: {ex.Message}");
            return null;
        }
    }
}
