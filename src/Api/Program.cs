var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
    c.SwaggerDoc("v1", new() { Title = "Azure Container Apps Demo", Version = "v1" }));

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

// APP_VERSION is set per revision via --set-env-vars in the GitHub Actions deploy step.
// CONTAINER_APP_REVISION is injected automatically by Azure at runtime.
var appVersion = Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0-local";
var revisionName = Environment.GetEnvironmentVariable("CONTAINER_APP_REVISION") ?? "local";

app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

app.MapGet("/api/info", () => new
{
    appVersion,
    revisionName,
    utc = DateTime.UtcNow
})
.WithName("GetInfo")
.WithSummary("Returns the app version and the Azure-assigned revision name for this instance");

// servedBy is included in every product so traffic splitting is visible in responses:
// fire repeated requests and watch the field alternate between revision versions.
var products = new[]
{
    new { id = 1, name = "Widget Pro",      price = 9.99m,  servedBy = appVersion },
    new { id = 2, name = "Gadget Plus",     price = 24.99m, servedBy = appVersion },
    new { id = 3, name = "Super Doohickey", price = 49.99m, servedBy = appVersion },
};

app.MapGet("/api/products", () => products)
.WithName("GetProducts")
.WithSummary("Returns products — servedBy alternates between revision versions when traffic is split");

app.Run();
