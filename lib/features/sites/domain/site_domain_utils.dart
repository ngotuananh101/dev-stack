/// Resolves a site domain from a template by replacing the first matching
/// placeholder with [folderName]. Supported placeholders (checked in order):
/// `[site-name]`, `{name}`, `{site-name}`. If none is present, returns
/// [template] unchanged.
String resolveDomainFromTemplate(String template, String folderName) {
  if (template.contains('[site-name]')) {
    return template.replaceAll('[site-name]', folderName);
  } else if (template.contains('{name}')) {
    return template.replaceAll('{name}', folderName);
  } else if (template.contains('{site-name}')) {
    return template.replaceAll('{site-name}', folderName);
  }
  return template;
}
