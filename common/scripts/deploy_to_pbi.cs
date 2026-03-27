// Script to load model.bim content into connected Power BI Desktop instance
// Run: TabularEditor.exe -L "demo" -S "C:\Users\dstrelnikov\Documents\SQL\common\scripts\deploy_to_pbi.cs"

var bimPath = @"C:\Users\dstrelnikov\Documents\SQL\common\model.bim";
var json = System.IO.File.ReadAllText(bimPath);
var newModel = Microsoft.AnalysisServices.Tabular.JsonSerializer.DeserializeDatabase(json);

// Copy tables from loaded model to connected model
foreach(var table in newModel.Model.Tables.ToList())
{
    var tableName = table.Name;
    // Remove existing table if present
    if(Model.Tables.Contains(tableName))
    {
        Model.Tables[tableName].Delete();
    }
}

// Save changes to remove old tables
Model.SaveToFolder(@"C:\Users\dstrelnikov\Documents\SQL\common\model_folder", SerializeOptions.Default);
Output("Model saved to folder. Now deploy from folder.");
