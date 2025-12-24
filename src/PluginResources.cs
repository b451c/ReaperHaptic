namespace Loupedeck.ReaperHapticPlugin
{
    using System;
    using System.IO;
    using System.Reflection;

    /// <summary>
    /// A helper class for managing plugin resources.
    /// Resource files must be embedded in the plugin assembly at compile time
    /// (Build Action = "Embedded Resource").
    /// </summary>
    internal static class PluginResources
    {
        private static Assembly _assembly;

        public static void Init(Assembly assembly)
        {
            _assembly = assembly ?? throw new ArgumentNullException(nameof(assembly));
        }

        public static Assembly Assembly => _assembly;

        /// <summary>
        /// Finds the first resource file with the specified file name.
        /// Returns the full name of the found resource file.
        /// </summary>
        public static string FindFile(string fileName)
        {
            if (_assembly == null)
            {
                throw new InvalidOperationException("PluginResources not initialized");
            }

            var resourceNames = _assembly.GetManifestResourceNames();
            foreach (var name in resourceNames)
            {
                if (name.EndsWith(fileName, StringComparison.OrdinalIgnoreCase))
                {
                    return name;
                }
            }

            throw new FileNotFoundException($"Resource not found: {fileName}");
        }

        /// <summary>
        /// Reads content of the specified image file, and returns the file content as a bitmap image.
        /// </summary>
        public static BitmapImage ReadImage(string resourceName)
        {
            using var stream = _assembly.GetManifestResourceStream(resourceName);
            if (stream == null)
            {
                throw new FileNotFoundException($"Resource stream not found: {resourceName}");
            }

            using var memoryStream = new MemoryStream();
            stream.CopyTo(memoryStream);
            return BitmapImage.FromArray(memoryStream.ToArray());
        }

        /// <summary>
        /// Tries to find and read an image file. Returns null if not found.
        /// </summary>
        public static BitmapImage TryReadImage(string fileName)
        {
            try
            {
                var resourceName = FindFile(fileName);
                return ReadImage(resourceName);
            }
            catch
            {
                return null;
            }
        }
    }
}
