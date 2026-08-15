using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using SkiaSharp;

namespace FunctionApp
{
    public class AddWatermarkToImageFunction
    {
        private static readonly string WatermarkFontPath = Path.Combine(AppContext.BaseDirectory, "Fonts", "Roboto-Regular.ttf");

        private readonly ILogger<AddWatermarkToImageFunction> _logger;

        public AddWatermarkToImageFunction(ILogger<AddWatermarkToImageFunction> logger)
        {
            _logger = logger;
        }

        [Function("AddWatermarkToImage")]
        public async Task Run(
            [BlobTrigger("input/{name}", Source = BlobTriggerSource.EventGrid, Connection = "AzureWebJobsStorage")] BlobClient inputBlob,
            [BlobInput("output", Connection = "AzureWebJobsStorage")] BlobContainerClient outputContainer,
            string name,
            CancellationToken cancellationToken)
        {
            _logger.LogInformation($"C# Blob trigger function processed image: {name}");

            try
            {
                using var downloadStream = new MemoryStream();
                await inputBlob.DownloadToAsync(downloadStream, cancellationToken);
                downloadStream.Position = 0;

                using var inputStream = new SKManagedStream(downloadStream);
                using var image = SKBitmap.Decode(inputStream);

                // Create a surface and canvas to draw on
                using var surface = SKSurface.Create(new SKImageInfo(image.Width, image.Height));
                var canvas = surface.Canvas;

                // Draw the original image onto the canvas
                canvas.DrawBitmap(image, 0, 0, SKSamplingOptions.Default);

                // Define the watermark text and paint
                string watermarkText = "AZURE FUNCTIONS ADDED A WATERMARK TEXT HERE";
                SKPaint paint = new SKPaint
                {
                    Color = SKColors.Red, // Change color as needed
                };
                using SKTypeface typeface = SKTypeface.FromFile(WatermarkFontPath)
                    ?? throw new InvalidOperationException($"Could not load watermark font from {WatermarkFontPath}");
                using SKFont font = new SKFont(typeface)
                {
                    Size = 36,
                };

                // Calculate the position to center the watermark
                float x = image.Width / 2;
                float y = (image.Height + font.Size) / 2;

                // Add the watermark to the image
                canvas.DrawText(watermarkText, x, y, SKTextAlign.Center, font, paint);

                // Encode the canvas to a JPEG image and upload it to the output container
                using var imageEncoded = surface.Snapshot().Encode();
                using var uploadStream = new MemoryStream();
                imageEncoded.SaveTo(uploadStream);
                uploadStream.Position = 0;

                await outputContainer.UploadBlobAsync(name, uploadStream, cancellationToken);
                _logger.LogInformation($"Watermark added to image: {name}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error adding watermark to image {Name}", name);
                throw;
            }
        }
    }
}
