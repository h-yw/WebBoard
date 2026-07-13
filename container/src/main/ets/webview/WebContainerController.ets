/**
 * WebContainerController — Shared controller for parent-child communication.
 *
 * ViewerPage creates an instance and passes it to WebContainer via @Link.
 * WebContainer sets up the handleBackPress function and updates nav style.
 * ViewerPage uses this in NavDestination.onBackPressed and title configuration.
 */
export class WebContainerController {
  handleBackPress: () => boolean = (): boolean => {
    return false
  }

  navStyle: number = -1
  customTitle: string = ''
  navigateBack: () => void = (): void => {}
}
