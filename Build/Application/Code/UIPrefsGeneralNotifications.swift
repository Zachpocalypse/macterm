/*###############################################################

	MacTerm
		© 1998-2020 by Kevin Grant.
		© 2001-2003 by Ian Anderson.
		© 1986-1994 University of Illinois Board of Trustees
		(see About box for full list of U of I contributors).
	
	This program is free software; you can redistribute it or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version
	2 of the License, or (at your option) any later version.
	
	This program is distributed in the hope that it will be
	useful, but WITHOUT ANY WARRANTY; without even the implied
	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
	PURPOSE.  See the GNU General Public License for more
	details.
	
	You should have received a copy of the GNU General Public
	License along with this program; if not, write to:
	
		Free Software Foundation, Inc.
		59 Temple Place, Suite 330
		Boston, MA  02111-1307
		USA

###############################################################*/

import SwiftUI

//
// IMPORTANT: Many "public" entities below are required
// in order to interact with Swift playgrounds.
//

@objc public enum UIPrefsGeneralNotifications_BackgroundAction : Int {
	case none // no action when notification appears while application is in the background
	case modifyIcon // show special indicator in the Dock
	case andBounceIcon // ...also animate Dock icon at least once
	case andBounceRepeatedly // ...and bounce again periodically
}

@objc public protocol UIPrefsGeneralNotifications_ActionHandling : NSObjectProtocol {
	// implement these functions to bind to button actions
	func dataUpdated()
	func playSelectedBellSound()
}

class UIPrefsGeneralNotifications_RunnerDummy : NSObject, UIPrefsGeneralNotifications_ActionHandling {
	// dummy used for debugging in playground (just prints function that is called)
	func dataUpdated() { print(#function) }
	func playSelectedBellSound() { print(#function) }
}

public class UIPrefsGeneralNotification_BellSoundItemModel : NSObject, Identifiable, ObservableObject {

	@objc public var uniqueID = UUID()
	@Published @objc public var soundName: String // sound name or other label
	@Published public var helpText: String // for help tag in pop-up menu
	@objc public static let offItemModel = UIPrefsGeneralNotification_BellSoundItemModel(soundName: "Off", helpText: "When terminal bell occurs, no sound will be played.")
	@objc public static let defaultItemModel = UIPrefsGeneralNotification_BellSoundItemModel(soundName: "Default", helpText: "When terminal bell occurs, alert sound will be played (set in System Preferences).")

	@objc public init(soundName: String, helpText: String? = nil) {
		self.soundName = soundName
		if let givenHelpText = helpText {
			self.helpText = givenHelpText
		} else {
			self.helpText = "When terminal bell occurs, sound with this name will be played."
		}
	}

}

public class UIPrefsGeneralNotifications_Model : UICommon_BaseModel, ObservableObject {

	@Published @objc public var bellSoundItems: [UIPrefsGeneralNotification_BellSoundItemModel] = []
	@Published @objc public var selectedBellSoundID = UIPrefsGeneralNotification_BellSoundItemModel.offItemModel.uniqueID {
		didSet(isOn) { ifWritebackEnabled { runner.playSelectedBellSound(); runner.dataUpdated() } }
	}
	@Published @objc public var visualBell = false {
		didSet(isOn) { ifWritebackEnabled { runner.dataUpdated() } }
	}
	@Published @objc public var bellNotificationInBackground = false {
		didSet(isOn) { ifWritebackEnabled { runner.dataUpdated() } }
	}
	@Published @objc public var backgroundNotificationAction: UIPrefsGeneralNotifications_BackgroundAction = .none {
		didSet(isOn) { ifWritebackEnabled { runner.dataUpdated() } }
	}
	public var runner: UIPrefsGeneralNotifications_ActionHandling

	@objc public init(runner: UIPrefsGeneralNotifications_ActionHandling) {
		self.runner = runner
	}

}

public struct UIPrefsGeneralNotification_BellSoundItemView : View {

	@EnvironmentObject private var itemModel: UIPrefsGeneralNotification_BellSoundItemModel

	public var body: some View {
		Text(itemModel.soundName).tag(itemModel.uniqueID)
			//.help(itemModel.helpText) // (add when SDK is updated)
	}

}

public struct UIPrefsGeneralNotifications_View : View {

	@EnvironmentObject private var viewModel: UIPrefsGeneralNotifications_Model

	func localizedLabelView(_ forType: UIPrefsGeneralNotifications_BackgroundAction) -> some View {
		var aTitle: String = ""
		switch forType {
		case .none:
			aTitle = "No alert"
		case .modifyIcon:
			aTitle = "Modify the Dock icon"
		case .andBounceIcon:
			aTitle = "…and bounce the Dock icon"
		case .andBounceRepeatedly:
			aTitle = "…and bounce repeatedly"
		}
		return Text(aTitle).tag(forType)
	}

	public var body: some View {
		VStack(
			alignment: .leading
		) {
			Spacer().asMacTermSectionSpacingV()
			Group {
				UICommon_OptionLineView("Terminal Bell", noDefaultSpacing: true) {
					Picker("", selection: $viewModel.selectedBellSoundID) {
						UIPrefsGeneralNotification_BellSoundItemView().environmentObject(UIPrefsGeneralNotification_BellSoundItemModel.offItemModel)
						UIPrefsGeneralNotification_BellSoundItemView().environmentObject(UIPrefsGeneralNotification_BellSoundItemModel.defaultItemModel)
						// TBD: how to insert dividing-line in this type of menu?
						//VStack { Divider().padding(.leading).disabled(true) } // this looks like a separator but is still selectable (SwiftUI bug?)
						ForEach(viewModel.bellSoundItems) { item in
							UIPrefsGeneralNotification_BellSoundItemView().environmentObject(item)
						}
					}.pickerStyle(PopUpButtonPickerStyle())
						.offset(x: -8, y: 0) // TEMPORARY; to eliminate left-padding created by Picker for empty label
						.frame(minWidth: 160, maxWidth: 160)
						//.help("The sound to play when a terminal bell occurs.") // (add when SDK is updated)
				}
				UICommon_OptionLineView("", noDefaultSpacing: true) {
					Toggle("Always use visual bell", isOn: $viewModel.visualBell)
						//.help("...") // (add when SDK is updated)
				}
				UICommon_OptionLineView("", noDefaultSpacing: true) {
					Text("When a bell sounds in an inactive window, a visual appears automatically.")
						.controlSize(.small)
						.fixedSize(horizontal: false, vertical: true)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
						.frame(maxWidth: 220)
						.offset(x: 18, y: 0) // try to align with checkbox label
				}
				Spacer().asMacTermSectionSpacingV()
				UICommon_OptionLineView("", noDefaultSpacing: true) {
					Toggle("Background notification on bell", isOn: $viewModel.bellNotificationInBackground)
						//.help("...") // (add when SDK is updated)
				}
			}
			Spacer().asMacTermSectionSpacingV()
			Group {
				UICommon_OptionLineView("When In Background", disableDefaultAlignmentGuide: true, noDefaultSpacing: true) {
					Picker("", selection: $viewModel.backgroundNotificationAction) {
						// TBD: how to insert dividing-line in this type of menu?
						localizedLabelView(.none)
						localizedLabelView(.modifyIcon)
						localizedLabelView(.andBounceIcon)
						localizedLabelView(.andBounceRepeatedly)
					}.pickerStyle(RadioGroupPickerStyle())
						.offset(x: -8, y: 0) // TEMPORARY; to eliminate left-padding created by Picker for empty label
						.alignmentGuide(.sectionAlignmentMacTerm, computeValue: { d in d[.top] + 8 }) // TEMPORARY; try to find a nicer way to do this (top-align both)
						//.help("How to respond to notifications when MacTerm is not the active application.") // (add when SDK is updated)
				}
			}
			Spacer().asMacTermSectionSpacingV()
			HStack {
				Text("Use “System Preferences” to further customize notification behavior.")
					.controlSize(.small)
					.fixedSize(horizontal: false, vertical: true)
					.lineLimit(3)
					.multilineTextAlignment(.leading)
					.frame(maxWidth: 400)
			}.withMacTermSectionLayout()
			Spacer().asMacTermSectionSpacingV()
			Spacer().layoutPriority(1)
		}
	}

}

public class UIPrefsGeneralNotifications_ObjC : NSObject {

	@objc public static func makeView(_ data: UIPrefsGeneralNotifications_Model) -> NSView {
		return NSHostingView<AnyView>(rootView: AnyView(UIPrefsGeneralNotifications_View().environmentObject(data)))
	}

}

public struct UIPrefsGeneralNotifications_Previews : PreviewProvider {
	public static var previews: some View {
		let data = UIPrefsGeneralNotifications_Model(runner: UIPrefsGeneralNotifications_RunnerDummy())
		data.bellSoundItems.append(UIPrefsGeneralNotification_BellSoundItemModel(soundName: "Basso"))
		data.bellSoundItems.append(UIPrefsGeneralNotification_BellSoundItemModel(soundName: "Glass"))
		data.bellSoundItems.append(UIPrefsGeneralNotification_BellSoundItemModel(soundName: "Hero"))
		return VStack {
			UIPrefsGeneralNotifications_View().background(Color(NSColor.windowBackgroundColor)).environment(\.colorScheme, .light).environmentObject(data)
			UIPrefsGeneralNotifications_View().background(Color(NSColor.windowBackgroundColor)).environment(\.colorScheme, .dark).environmentObject(data)
		}
	}
}
