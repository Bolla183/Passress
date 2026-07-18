const COLOR_HEX: Record<string, string> = {
  black: '#1c1c1c', white: '#f3f2ee', ivory: '#f0ead8', cream: '#efe6d3',
  beige: '#d8c7a8', camel: '#b6864f', tan: '#c6a06e',
  red: '#7c2c2c', burgundy: '#5c2430', navy: '#212c42',
  charcoal: '#3c3b3a', grey: '#8d8a83', gray: '#8d8a83',
  taupe: '#a9967f', stone: '#c8c0ac', espresso: '#4a3527',
  olive: '#5c5a3c', green: '#3c4d3a', brown: '#5a4433',
};

export function hexForColor(name: string | undefined | null): string {
  const key = String(name ?? '').toLowerCase().trim();
  if (COLOR_HEX[key]) return COLOR_HEX[key];
  for (const candidate of Object.keys(COLOR_HEX)) {
    if (key.includes(candidate)) return COLOR_HEX[candidate];
  }
  return '#c8c0ac';
}
