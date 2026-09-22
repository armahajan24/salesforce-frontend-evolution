<!--
  Thin dev-verification harness only, NOT part of the LWC deliverable itself.
  LWC has no standalone-URL launcher the way an Aura .app does, and building a
  full FlexiPage/CustomApplication just to preview one component would be more
  scaffolding than the comparison is trying to measure. Aura can host a plain
  LWC directly (the reverse is not supported), so this lets us open and smoke
  test c-account-dashboard-lwc in a real browser against the real org.
-->
<aura:application access="global" extends="force:slds">
    <c:accountDashboardLwc/>
</aura:application>
