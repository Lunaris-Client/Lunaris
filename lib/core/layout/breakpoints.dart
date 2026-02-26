enum LayoutBreakpoint { mobile, tablet, desktop }

LayoutBreakpoint layoutBreakpointOf(double width) {
  if (width >= 1024) return LayoutBreakpoint.desktop;
  if (width >= 600) return LayoutBreakpoint.tablet;
  return LayoutBreakpoint.mobile;
}
