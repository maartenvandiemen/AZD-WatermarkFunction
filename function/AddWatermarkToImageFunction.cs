using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using SkiaSharp;

namespace FunctionApp
{
    public class AddWatermarkToImageFunction
    {
        private readonly ILogger<AddWatermarkToImageFunction> _logger;

        public AddWatermarkToImageFunction(ILogger<AddWatermarkToImageFunction> logger)
        {
            _logger = logger;
        }

        [Function("AddWatermarkToImage")]
        [BlobOutput("output/{name}", Connection = "AzureWebJobsStorage")]
        public byte[] Run(
            //Convert this back to System.io.Stream when this issue is solved: https://github.com/Azure/azure-functions-dotnet-worker/issues/1969
            [BlobTrigger("input/{name}", Connection = "AzureWebJobsStorage")] byte[] blob, 
            string name)
        {
            _logger.LogInformation($"C# Blob trigger function processed image: {name}");

            try
            {
                using (var stream = new MemoryStream(blob))
                using (var inputStream = new SKManagedStream(stream))
                using (var image = SKBitmap.Decode(inputStream))
                {
                    // Create a surface and canvas to draw on
                    using (var surface = SKSurface.Create(new SKImageInfo(image.Width, image.Height)))
                    using (var canvas = surface.Canvas)
                    {
                        // Draw the original image onto the canvas
                        canvas.DrawBitmap(image, 0, 0);

                        // Define the watermark text and paint
                        string watermarkText = "AZURE FUNCTIONS ADDED A WATERMARK TEXT HERE";
                        SKPaint paint = new SKPaint
                        {
                            Color = SKColors.Red, // Change color as needed
                        };
                        SKFont font = new SKFont
                        {
                            Size = 36,
                        };

                        // Calculate the position to center the watermark
                        float x = image.Width / 2;
                        float y = (image.Height + font.Size) / 2;

                        // Add the watermark to the image
                        canvas.DrawText(watermarkText, x, y, SKTextAlign.Center, font, paint);

                        // Encode the canvas to a JPEG image
                        using (var imageEncoded = surface.Snapshot().Encode())
                        {
                            using (var memoryStream = new MemoryStream())
                            {
                                imageEncoded.SaveTo(memoryStream);
                                _logger.LogInformation($"Watermark added to image: {name}");
                                return memoryStream.ToArray();
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error adding watermark to image {name}: {ex.Message}");
                throw;
            }
        }
    }
}
