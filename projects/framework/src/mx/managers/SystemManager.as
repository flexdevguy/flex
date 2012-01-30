////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2003-2007 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package mx.managers
{

import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.Graphics;
import flash.display.InteractiveObject;
import flash.display.Loader;
import flash.display.LoaderInfo;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.display.Stage;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.EventPhase;
import flash.events.IEventDispatcher;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.getClassByAlias;
import flash.net.registerClassAlias;
import flash.system.ApplicationDomain;
import flash.system.Capabilities;
import flash.text.Font;
import flash.text.TextFormat;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;

import mx.core.EmbeddedFontRegistry;
import mx.core.FlexSprite;
import mx.core.IChildList;
import mx.core.IFlexDisplayObject;
import mx.core.IFlexModuleFactory;
import mx.core.IInvalidating;
import mx.core.IRawChildrenContainer;
import mx.core.IUIComponent;
import mx.core.RSLItem;
import mx.core.Singleton;
import mx.core.TextFieldFactory;
import mx.core.mx_internal;
import mx.events.FlexEvent;
import mx.events.FocusRequest;
import mx.events.MarshalEvent;
import mx.events.ModalWindowRequest;
import mx.events.PopUpRequest;
import mx.events.ShowAlertRequest;
import mx.events.SizeRequest;
import mx.messaging.config.LoaderConfig;
import mx.preloaders.DownloadProgressBar;
import mx.preloaders.Preloader;
import mx.resources.IResourceManager;
import mx.resources.ResourceBundle;
import mx.resources.ResourceManager;
import mx.sandbox.IChildAccess;
import mx.sandbox.IParentAccess;
import mx.sandbox.ISandboxBridgeGroup;
import mx.sandbox.SandboxBridgeGroup;
import mx.styles.ISimpleStyleClient;
import mx.styles.IStyleClient;
import mx.styles.StyleManager;
import mx.events.EventListenerRequest;
import mx.events.MarshalMouseEvent;
import mx.events.SandboxBridgeRequest;
import mx.events.SandboxBridgeEvent;
import mx.utils.EventUtil;
import mx.utils.NameUtil;
import mx.utils.ObjectUtil;
import mx.utils.SandboxUtil;
import mx.events.ResizeEvent;


// NOTE: Minimize the non-Flash classes you import here.
// Any dependencies of SystemManager have to load in frame 1,
// before the preloader, or anything else, can be displayed.

use namespace mx_internal;

//--------------------------------------
//  Events
//--------------------------------------

/**
 *  Dispatched when the application has finished initializing
 *
 *  @eventType mx.events.FlexEvent.APPLICATION_COMPLETE
 */
[Event(name="applicationComplete", type="mx.events.FlexEvent")]

/**
 *  Dispatched every 100 milliseconds when there has been no keyboard
 *  or mouse activity for 1 second.
 *
 *  @eventType mx.events.FlexEvent.IDLE
 */
[Event(name="idle", type="mx.events.FlexEvent")]

/**
 *  Dispatched when the Stage is resized.
 *
 *  @eventType flash.events.Event.RESIZE
 */
[Event(name="resize", type="flash.events.Event")]

/**
 *  The SystemManager class manages an application window.
 *  Every application that runs on the desktop or in a browser
 *  has an area where the visuals of the application are 
 *  displayed.  
 *  It may be a window in the operating system
 *  or an area within the browser.  That area is an application window
 *  and different from an instance of <code>mx.core.Application</code>, which
 *  is the main, or top-level, window within an application.
 *
 *  <p>Every application has a SystemManager.  
 *  The SystemManager sends an event if
 *  the size of the application window changes (you cannot change it from
 *  within the application, but only through interaction with the operating
 *  system window or browser).  It parents all displayable things within the
 *  application like the main mx.core.Application instance and all popups, 
 *  tooltips, cursors, and so on.  Any object parented by the SystemManager is
 *  considered to be a top-level window, even tooltips and cursors.</p>
 *
 *  <p>The SystemManager also switches focus between top-level windows if there 
 *  are more than one IFocusManagerContainer displayed and users are interacting
 *  with components within the IFocusManagerContainers.  </p>
 *
 *  <p>All keyboard and mouse activity that is not expressly trapped is seen by
 *  the SystemManager, making it a good place to monitor activity should you need
 *  to do so.</p>
 *
 *  <p>If an application is loaded into another application, a SystemManager
 *  will still be created, but will not manage an application window,
 *  depending on security and domain rules.
 *  Instead, it will be the <code>content</code> of the <code>Loader</code> 
 *  that loaded it and simply serve as the parent of the sub-application</p>
 *
 *  <p>The SystemManager maintains multiple lists of children, one each for tooltips, cursors,
 *  popup windows.  This is how it ensures that popup windows "float" above the main
 *  application windows and that tooltips "float" above that and cursors above that.
 *  If you simply examine the <code>numChildren</code> property or 
 *  call the <code>getChildAt()</code> method on the SystemManager, you are accessing
 *  the main application window and any other windows that aren't popped up.  To get the list
 *  of all windows, including popups, tooltips and cursors, use 
 *  the <code>rawChildren</code> property.</p>
 *
 *  <p>The SystemManager is the first display class created within an application.
 *  It is responsible for creating an <code>mx.preloaders.Preloader</code> that displays and
 *  <code>mx.preloaders.DownloadProgressBar</code> while the application finishes loading,
 *  then creates the <code>mx.core.Application</code> instance.</p>
 */
public class SystemManager extends MovieClip
						   implements IChildList, IFlexDisplayObject,
						   IFlexModuleFactory, ISystemManager2, IParentAccess
{
    include "../core/Version.as";

	//--------------------------------------------------------------------------
	//
	//  Class constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  The number of milliseconds that must pass without any user activity
	 *  before SystemManager starts dispatching 'idle' events.
	 */
	private static const IDLE_THRESHOLD:Number = 1000;

	/**
	 *  @private
	 *  The number of milliseconds between each 'idle' event.
	 */
	private static const IDLE_INTERVAL:Number = 100;

	//--------------------------------------------------------------------------
	//
	//  Class variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  An array of SystemManager instances loaded as child app domains
	 */
	mx_internal static var allSystemManagers:Dictionary = new Dictionary(true);

	/**
	 *  @private
	 *  The last SystemManager instance loaded as child app domains
	 */
	mx_internal static var lastSystemManager:SystemManager;

	//--------------------------------------------------------------------------
	//
	//  Class methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  If a class wants to be notified when the Application instance
	 *  has been initialized, then it registers a callback here.
	 *  By using a callback mechanism, we avoid adding unwanted
	 *  linker dependencies on classes like HistoryManager and DragManager.
	 */
	mx_internal static function registerInitCallback(initFunction:Function):void
	{
		if (!allSystemManagers || !lastSystemManager)
		{
			return;
		}

		var sm:SystemManager = lastSystemManager;

		// If this function is called late (after we're done invoking the
		// callback functions for the last time), then just invoke
		// the callback function immediately.
		if (sm.doneExecutingInitCallbacks)
			initFunction(sm);
		else
			sm.initCallbackFunctions.push(initFunction);
	}

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructor.
	 *
	 *  <p>This is the starting point for all Flex applications.
	 *  This class is set to be the root class of a Flex SWF file.
	 *  The Player instantiates an instance of this class,
	 *  causing this constructor to be called.</p>
	 */
	public function SystemManager()
	{
		super();

		// Loaded SWFs don't get a stage right away
		// and shouldn't override the main SWF's setting anyway.
		if (stage)
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
		}

		// If we don't have a stage then we are not top-level,
		// unless there are no other top-level managers, in which
		// case we got loaded by a non-Flex shell or are sandboxed.
		if (SystemManagerGlobals.topLevelSystemManagers.length > 0 && !stage)
			topLevel = false;

		if (!stage)
			isStageRoot = false;

		if (topLevel)
			SystemManagerGlobals.topLevelSystemManagers.push(this);

		lastSystemManager = this;

		var compiledLocales:Array = info()["compiledLocales"];
		ResourceBundle.mx_internal::locale =
			compiledLocales != null && compiledLocales.length > 0 ?
			compiledLocales[0] :
			"en_US";

		executeCallbacks();

		// Make sure to stop the playhead on the current frame.
		stop();

		// Add safeguard in case bug 129782 shows up again.
		if (topLevel && currentFrame != 1)
		{
			throw new Error("The SystemManager constructor was called when the currentFrame was at " + currentFrame +
							" Please add this SWF to bug 129782.");
		}

		// Listen for the last frame (param is 0-indexed) to be executed.
		//addFrameScript(totalFrames - 1, frameEndHandler);

		if (root && root.loaderInfo)
			root.loaderInfo.addEventListener(Event.INIT, initHandler);
			
	}

	
	
    /**
	 *  @private
	 */
    private function deferredNextFrame():void
    {
        if (currentFrame + 1 > totalFrames)
            return;

        if (currentFrame + 1 <= framesLoaded)
		{
            nextFrame();
		}
        else
        {
            // Next frame isn't baked yet, so we'll check back...
    		nextFrameTimer = new Timer(100);
		    nextFrameTimer.addEventListener(TimerEvent.TIMER,
											nextFrameTimerHandler);
		    nextFrameTimer.start();
        }
    }

	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  This flag remembers whether we're going to call executeCallbacks again
	 */
	private var doneExecutingInitCallbacks:Boolean = false;

	/**
	 *  @private
	 *  This array stores pointers to all the init callback functions for this
	 *  system manager.
	 *  See registerInitCallback() for more information.
	 */
	private var initCallbackFunctions:Array = [];

	/**
	 *  @private
	 */
	private var initialized:Boolean = false;

	/**
	 *  @private
	 *  Whether we are in the top-level list or not;
	 *  top-level means we are the highest level SystemManager
	 *  for this stage.
	 */
	// VERSION_SKEW 
	// TODODJL: still need this? change from private to mx_internal so SystemManagerProxy can change it
	mx_internal var topLevel:Boolean = true;

	/**
	 *  @private
	 *  Whether we are the stage root or not.
	 *  We are only the stage root if we were the root
	 *  of the first SWF that got loaded by the player.
	 *  Otherwise we could be top level but not stage root
	 *  if we are loaded by some other non-Flex shell
	 *  or are sandboxed.
	 */
	private var isStageRoot:Boolean = true;

	/**
	 *  @private
	 *  Whether we are the first SWF loaded into a bootstrap
	 *  and therefore, the topLevelRoot
	 */
	private var isBootstrapRoot:Boolean = false;

	/**
	 *  @private
	 *  If we're not top level, then we delegate many things
	 *  to the top level SystemManager.
	 */
	private var _topLevelSystemManager:ISystemManager;

	/**
	 * cached value of the stage.
	 */
	private var _stage:Stage;
	
	/**
	 *  Depth of this object in the containment hierarchy.
	 *  This number is used by the measurement and layout code.
	 */
	mx_internal var nestLevel:int = 0;

	/**
	 *  @private
	 */
	private var rslSizes:Array = null;

	/**
	 *  @private
	 *  A reference to the preloader.
	 */
	private var preloader:Preloader;

	/**
	 *  @private
	 *  The mouseCatcher is the 0th child of the SystemManager,
	 *  behind the application, which is child 1.
	 *  It is the same size as the stage and is filled with
	 *  transparent pixels; i.e., they've been drawn, but with alpha 0.
	 *
	 *  Its purpose is to make every part of the stage
	 *  able to detect the mouse.
	 *  For example, a Button puts a mouseUp handler on the SystemManager
	 *  in order to capture mouseUp events that occur outside the Button.
	 *  But if the children of the SystemManager don't have "drawn-on"
	 *  pixels everywhere, the player won't dispatch the mouseUp.
	 *  We can't simply fill the SystemManager itself with
	 *  transparent pixels, because the player's pixel detection
	 *  logic doesn't look at pixels drawn into the root DisplayObject.
	 *
	 *  Here is an example of what would happen without the mouseCatcher:
	 *  Run a fixed-size Application (e.g. width="600" height="600")
	 *  in the standalone player. Make the player window larger
	 *  to reveal part of the stage. Press a Button, drag off it
	 *  into the stage area, and release the mouse button.
	 *  Without the mouseCatcher, the Button wouldn't return to its "up" state.
	 */
	 // VERSION_SKEW change from private to mx_internal so SystemManagerProxy can set.
	mx_internal var mouseCatcher:Sprite;

	/**
	 *  @private
	 *  The top level window.
	 */
	mx_internal var topLevelWindow:IUIComponent;

	/**
	 *  @private
	 *  List of top level windows.
	 */
	private var forms:Array = [];

	/**
	 *  @private
	 *  The current top level window.
	 *
	 * 	Will be of type IFocusManagerContainer if the form
	 *  in the top-level system manager's application domain
	 *  or a child of that application domain. Otherwise the
	 *  form will be of type RemotePopUp.
	 */
	private var form:Object;

	/**
	 *  @private
	 *  Number of frames since the last mouse or key activity.
	 */
	mx_internal var idleCounter:int = 0;

	/**
	 *  @private
	 *  The Timer used to determine when to dispatch idle events.
	 */
	private var idleTimer:Timer;

    /**
	 *  @private
	 *  A timer used when it is necessary to wait before incrementing the frame
	 */
	private var nextFrameTimer:Timer = null;

	//--------------------------------------------------------------------------
	//
	//  Overridden properties: DisplayObject
	//
	//--------------------------------------------------------------------------

    //----------------------------------
    //  height
    //----------------------------------

	/**
	 *  @private
	 */
	private var _height:Number;

	/**
	 *  The height of this object.  For the SystemManager
	 *  this should always be the width of the stage unless the application was loaded
	 *  into another application.  If the application was not loaded
	 *  into another application, setting this value has no effect.
	 */
	override public function get height():Number
	{
		return _height;
	}

	//----------------------------------
	//  stage
	//----------------------------------

	/**
	 *  @private
	 *  get the main stage if we're loaded into another swf in the same sandbox
	 */
	override public function get stage():Stage
	{
		if (_stage)
			return _stage;
			
		var s:Stage = super.stage;
		if (s)
		{
			_stage = s;
			return s;
		}

		if (!topLevel && _topLevelSystemManager)
		{
			_stage = _topLevelSystemManager.stage; 
			return _stage;
		}

		// Case for version skew, we are a top level system manager, but
		// a child of the top level root system manager and we have access 
		// to the stage. 
		if (!isStageRoot && topLevel)
		{
			var root:DisplayObject = getTopLevelRoot();
			if (root)
			{
				_stage = root.stage;
				return _stage;
			}
		}

		return null;
	}

    //----------------------------------
    //  width
    //----------------------------------

	/**
	 *  @private
	 */
	private var _width:Number;

	/**
	 *  The width of this object.  For the SystemManager
	 *  this should always be the width of the stage unless the application was loaded
	 *  into another application.  If the application was not loaded
	 *  into another application, setting this value will have no effect.
	 */
	override public function get width():Number
	{
		return _width;
	}

	//--------------------------------------------------------------------------
	//
	//  Overridden properties: DisplayObjectContainer
	//
	//--------------------------------------------------------------------------

    //----------------------------------
    //  numChildren
    //----------------------------------

	/**
	 *  The number of non-floating windows.  This is the main application window
	 *  plus any other windows added to the SystemManager that are not popups,
	 *  tooltips or cursors.
	 */
	override public function get numChildren():int
	{
		return noTopMostIndex - applicationIndex;
	}

	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------

    //----------------------------------
    //  application
    //----------------------------------

	/**
	 *  The application parented by this SystemManager.
	 *  SystemManagers create an instance of an Application
	 *  even if they are loaded into another Application.
	 *  Thus, this may not match mx.core.Application.application
	 *  if the SWF has been loaded into another application.
	 *  <p>Note that this property is not typed as mx.core.Application
	 *  because of load-time performance considerations
	 *  but can be coerced into an mx.core.Application.</p>
	 */
	public function get application():IUIComponent
	{
		return IUIComponent(_document);
	}

	//----------------------------------
	//  applicationIndex
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the applicationIndex property.
	 */
	private var _applicationIndex:int = 1;

	/**
	 *  @private
	 *  The index of the main mx.core.Application window, which is
	 *  effectively its z-order.
	 */
	mx_internal function get applicationIndex():int
	{
		return _applicationIndex;
	}

	/**
	 *  @private
	 */
	mx_internal function set applicationIndex(value:int):void
	{
		_applicationIndex = value;
	}

	//----------------------------------
	//  cursorChildren
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the cursorChildren property.
	 */
	private var _cursorChildren:SystemChildrenList;

	/**
	 *  @inheritDoc
	 */
	public function get cursorChildren():IChildList
	{
		if (!topLevel)
			return _topLevelSystemManager.cursorChildren;

		if (!_cursorChildren)
		{
			_cursorChildren = new SystemChildrenList(this,
				new QName(mx_internal, "toolTipIndex"),
				new QName(mx_internal, "cursorIndex"));
		}

		return _cursorChildren;
	}

	//----------------------------------
	//  cursorIndex
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the toolTipIndex property.
	 */
	private var _cursorIndex:int = 0;

	/**
	 *  @private
	 *  The index of the highest child that is a cursor.
	 */
	mx_internal function get cursorIndex():int
	{
		return _cursorIndex;
	}

	/**
	 *  @private
	 */
	mx_internal function set cursorIndex(value:int):void
	{
		var delta:int = value - _cursorIndex;
		_cursorIndex = value;
	}

    //----------------------------------
    //  document
    //----------------------------------

	/**
	 *  @private
	 *  Storage for the document property.
	 */
	private var _document:Object;

	/**
	 *  @inheritDoc
	 */
	public function get document():Object
	{
		return _document;
	}

	/**
	 *  @private
	 */
	public function set document(value:Object):void
	{
		_document = value;
	}

	//----------------------------------
	//  embeddedFontList
	//----------------------------------

   	/**
   	 *  @private
   	 *  Storage for the fontList property.
   	 */
   	private var _fontList:Object = null;

	/**
	 *  A table of embedded fonts in this application.  The 
	 *  object is a table indexed by the font name.
	 */
	public function get embeddedFontList():Object
	{
	    if (_fontList == null)
	    {
            _fontList = {};

            var o:Object = info()["fonts"];

			var p:String;

            for (p in o)
         	{
                _fontList[p] = o[p];
            }

            // FIXME: font rules across SWF boundaries have not been finalized!

			// Top level systemManager may not be defined if SWF is loaded
			// as a background image in download progress bar.
      		if (!topLevel && _topLevelSystemManager)                   
   		    {
		        var fl:Object = _topLevelSystemManager.embeddedFontList;
			    for (p in fl)
			    {
			        _fontList[p] = fl[p];
			    }
		    }
		}

		return _fontList;
	}

    //----------------------------------
    //  explicitHeight
    //----------------------------------

	/**
	 *  @private
	 */
	private var _explicitHeight:Number;

	/**
	 *  The explicit width of this object.  For the SystemManager
	 *  this should always be NaN unless the application was loaded
	 *  into another application.  If the application was not loaded
	 *  into another application, setting this value has no effect.
	 */
	public function get explicitHeight():Number
	{
		return _explicitHeight;
	}

	/**
	 *  @private
	 */
    public function set explicitHeight(value:Number):void
    {
        _explicitHeight = value;
	}

    //----------------------------------
    //  explicitWidth
    //----------------------------------

	/**
	 *  @private
	 */
	private var _explicitWidth:Number;

	/**
	 *  The explicit width of this object.  For the SystemManager
	 *  this should always be NaN unless the application was loaded
	 *  into another application.  If the application was not loaded
	 *  into another application, setting this value has no effect.
	 */
	public function get explicitWidth():Number
	{
		return _explicitWidth;
	}

	/**
	 *  @private
	 */
    public function set explicitWidth(value:Number):void
    {
        _explicitWidth = value;
	}

    //----------------------------------
    //  focusPane
    //----------------------------------

    /**
     *  @private
     */
    private var _focusPane:Sprite;

	/**
     *  @copy mx.core.UIComponent#focusPane
	 */
    public function get focusPane():Sprite
	{
		return _focusPane;
	}

	/**
     *  @private
     */
    public function set focusPane(value:Sprite):void
    {
        if (value)
        {
            addChild(value);

            value.x = 0;
			value.y = 0;
            value.scrollRect = null;

            _focusPane = value;
        }
        else
        {
            removeChild(_focusPane);

            _focusPane = null;
        }
    }

	//----------------------------------
	//  info
	//----------------------------------

    /**
	 *  @private
     */
    public function info():Object
    {
        return {};
    }

    //----------------------------------
    //  measuredHeight
    //----------------------------------

	/**
	 *  The measuredHeight is the explicit or measuredHeight of 
	 *  the main mx.core.Application window
	 *  or the starting height of the SWF if the main window 
	 *  has not yet been created or does not exist.
	 */
	public function get measuredHeight():Number
	{
		return topLevelWindow ?
			   topLevelWindow.getExplicitOrMeasuredHeight() :
			   loaderInfo.height;
	}

    //----------------------------------
    //  measuredWidth
    //----------------------------------

	/**
	 *  The measuredWidth is the explicit or measuredWidth of 
	 *  the main mx.core.Application window,
	 *  or the starting width of the SWF if the main window 
	 *  has not yet been created or does not exist.
	 */
	public function get measuredWidth():Number
	{
		return topLevelWindow ?
			   topLevelWindow.getExplicitOrMeasuredWidth() :
			   loaderInfo.width;
	}

	//----------------------------------
	//  noTopMostIndex
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the noTopMostIndex property.
	 */
	private var _noTopMostIndex:int = 0;

	/**
	 *  @private
	 *  The index of the highest child that isn't a topmost/popup window
	 */
	mx_internal function get noTopMostIndex():int
	{
		return _noTopMostIndex;
	}

	/**
	 *  @private
	 */
	mx_internal function set noTopMostIndex(value:int):void
	{
		var delta:int = value - _noTopMostIndex;
		_noTopMostIndex = value;
		topMostIndex += delta;
	}

	//----------------------------------
	//  $numChildren
	//----------------------------------

	/**
	 *  @private
	 *  This property allows access to the Player's native implementation
	 *  of the numChildren property, which can be useful since components
	 *  can override numChildren and thereby hide the native implementation.
	 *  Note that this "base property" is final and cannot be overridden,
	 *  so you can count on it to reflect what is happening at the player level.
	 */
	mx_internal final function get $numChildren():int
	{
		return super.numChildren;
	}

    //----------------------------------
    //  numModalWindows
    //----------------------------------

	/**
	 *  @private
	 *  Storage for the numModalWindows property.
	 */
	private var _numModalWindows:int = 0;

	/**
	 *  The number of modal windows.  Modal windows don't allow
	 *  clicking in another windows which would normally
	 *  activate the FocusManager in that window.  The PopUpManager
	 *  modifies this count as it creates and destroys modal windows.
	 */
	public function get numModalWindows():int
	{
		return _numModalWindows;
	}

	/**
	 *  @private
	 */
	public function set numModalWindows(value:int):void
	{
		_numModalWindows = value;
	}

    //----------------------------------
    //  preloaderBackgroundAlpha
    //----------------------------------

	/**
	 *	The background alpha used by the child of the preloader.
	 */
	public function get preloaderBackgroundAlpha():Number
	{
        return info()["backgroundAlpha"];
	}

    //----------------------------------
    //  preloaderBackgroundColor
    //----------------------------------

	/**
	 *	The background color used by the child of the preloader.
	 */
	public function get preloaderBackgroundColor():uint
	{
		var value:* = info()["backgroundColor"];
		if (value == undefined)
			return StyleManager.NOT_A_COLOR;
		else
			return StyleManager.getColorName(value);
	}

    //----------------------------------
    //  preloaderBackgroundImage
    //----------------------------------

	/**
	 *	The background color used by the child of the preloader.
	 */
	public function get preloaderBackgroundImage():Object
	{
        return info()["backgroundImage"];
	}

	//----------------------------------
    //  preloaderBackgroundSize
    //----------------------------------

	/**
	 *	The background size used by the child of the preloader.
	 */
	public function get preloaderBackgroundSize():String
	{
        return info()["backgroundSize"];
	}

	//----------------------------------
	//  popUpChildren
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the popUpChildren property.
	 */
	private var _popUpChildren:SystemChildrenList;

	/**
	 *  @inheritDoc
	 */
	public function get popUpChildren():IChildList
	{
		if (!topLevel)
			return _topLevelSystemManager.popUpChildren;

		if (!_popUpChildren)
		{
			_popUpChildren = new SystemChildrenList(this,
				new QName(mx_internal, "noTopMostIndex"),
				new QName(mx_internal, "topMostIndex"));
		}

		return _popUpChildren;
	}

	//----------------------------------
	//  rawChildren
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the rawChildren property.
	 */
	private var _rawChildren:SystemRawChildrenList;

	/**
	 *  @inheritDoc
	 */
	public function get rawChildren():IChildList
	{
		//if (!topLevel)
		//	return _topLevelSystemManager.rawChildren;

		if (!_rawChildren)
			_rawChildren = new SystemRawChildrenList(this);

		return _rawChildren;
	}


	//--------------------------------------------------------------------------
	//  sandbox bridge group
	//--------------------------------------------------------------------------
	
	/**
	 * @private
	 * 
	 * Represents the related parent and child sandboxs this SystemManager may 
	 * communicate with.
	 */
	private var _sandboxBridgeGroup:ISandboxBridgeGroup;
	
	
	public function get sandboxBridgeGroup():ISandboxBridgeGroup
	{
		if (topLevel)
			return _sandboxBridgeGroup;
		else if (topLevelSystemManager)
			return ISystemManager2(topLevelSystemManager).sandboxBridgeGroup;
			
		return null;
	}
	
	public function set sandboxBridgeGroup(bridgeGroup:ISandboxBridgeGroup):void
	{
		if (topLevel)
			_sandboxBridgeGroup = bridgeGroup;
		else if (topLevelSystemManager)
			SystemManager(topLevelSystemManager).sandboxBridgeGroup = bridgeGroup;
					
	}
	
	//--------------------------------------------------------------------------
	//  screen
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Storage for the screen property.
	 */
	private var _screen:Rectangle;

	/**
	 *  @inheritDoc
	 */
	public function get screen():Rectangle
	{
		if (!_screen)
			Stage_resizeHandler();

		// VERSION_SKEW
		if (!isStageRoot)
		{
			Stage_resizeHandler();
		}
		return _screen;
	}

	//----------------------------------
	//  toolTipChildren
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the toolTipChildren property.
	 */
	private var _toolTipChildren:SystemChildrenList;

	/**
	 *  @inheritDoc
	 */
	public function get toolTipChildren():IChildList
	{
		if (!topLevel)
			return _topLevelSystemManager.toolTipChildren;

		if (!_toolTipChildren)
		{
			_toolTipChildren = new SystemChildrenList(this,
				new QName(mx_internal, "topMostIndex"),
				new QName(mx_internal, "toolTipIndex"));
		}

		return _toolTipChildren;
	}

	//----------------------------------
	//  toolTipIndex
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the toolTipIndex property.
	 */
	private var _toolTipIndex:int = 0;

	/**
	 *  @private
	 *  The index of the highest child that is a tooltip
	 */
	mx_internal function get toolTipIndex():int
	{
		return _toolTipIndex;
	}

	/**
	 *  @private
	 */
	mx_internal function set toolTipIndex(value:int):void
	{
		var delta:int = value - _toolTipIndex;
		_toolTipIndex = value;
		cursorIndex += delta;
	}

	//----------------------------------
	//  topLevelSystemManager
	//----------------------------------

	/**
	 *  Returns the SystemManager responsible for the application window.  This will be
	 *  the same SystemManager unless this application has been loaded into another
	 *  application.
	 */
	public function get topLevelSystemManager():ISystemManager
	{
		if (topLevel)
			return this;

		return _topLevelSystemManager;
	}

	//----------------------------------
	//  topMostIndex
	//----------------------------------

	/**
	 *  @private
	 *  Storage for the topMostIndex property.
	 */
	private var _topMostIndex:int = 0;

	/**
	 *  @private
	 *  The index of the highest child that is a topmost/popup window
	 */
	mx_internal function get topMostIndex():int
	{
		return _topMostIndex;
	}

	mx_internal function set topMostIndex(value:int):void
	{
		var delta:int = value - _topMostIndex;
		_topMostIndex = value;
		toolTipIndex += delta;
	}

	// VERSION_SKEW
	/**
	 * @private
	 * 
	 * true if dispatching a mouse bridge event. We don't want to 
	 * handle our own event.
	 */
	private var isDispatchingBridgeMouseEvent:Boolean;
	
	/**
	 * @private
	 * 
	 * true if redipatching a resize event.
	 */
	 // TODODJL: may be a better of way than dispathing resize event.
	private var isDispatchingResizeEvent:Boolean;
	
	/**
	 * @private
	 * 
	 * Used to locate untrusted forms. Maps string ids to Objects.
	 * The object make be the SystemManagerProxy of a form or it may be
	 * the bridge to the child application where the object lives.
	 */
	private var idToPlaceholder:Object;
	
	private var eventProxy:EventProxy;
	private var weakReferenceProxies:Dictionary = new Dictionary(true);
	private var strongReferenceProxies:Dictionary = new Dictionary(false);

	//--------------------------------------------------------------------------
	//
	//  Overridden methods: EventDispatcher
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Only create idle events if someone is listening.
	 */
	override public function addEventListener(type:String, listener:Function,
											  useCapture:Boolean = false,
											  priority:int = 0,
											  useWeakReference:Boolean = false):void
	{
		// These two events will dispatched to applications in sandboxes.
		if (type == FlexEvent.RENDER || type == FlexEvent.ENTER_FRAME)
		{
			if (type == FlexEvent.RENDER)
				type = Event.RENDER;
			else
				type = Event.ENTER_FRAME;
				
			try
			{
				// TODODJL: problem loading untrusted children, stage is null and we don't 
				// add the listener we wanted.
				if (stage)
					stage.addEventListener(type, listener, useCapture, priority, useWeakReference);
				else
					super.addEventListener(type, listener, useCapture, priority, useWeakReference);
				
			}
			catch (error:SecurityError)
			{
				super.addEventListener(type, listener, useCapture, priority, useWeakReference);
			}
		
			if (stage && type == Event.RENDER)
				stage.invalidate();

			return;
		}

		if (type == MouseEvent.MOUSE_MOVE || type == MouseEvent.MOUSE_UP || type == MouseEvent.MOUSE_DOWN 
				|| type == Event.ACTIVATE || type == Event.DEACTIVATE)
		{
			// also listen to stage if allowed
			try
			{
				if (stage)
				{
					var newListener:StageEventProxy = new StageEventProxy(listener);
					stage.addEventListener(type, newListener.stageListener, false, priority, useWeakReference);
					if (useWeakReference)
						weakReferenceProxies[listener] = newListener;
					else
						strongReferenceProxies[listener] = newListener;
				}
			}
			catch (error:SecurityError)
			{
			}
		}
		
		if (hasSandboxBridges())
		{
			if (!eventProxy)
				eventProxy = new EventProxy(this);

			var actualType:String = EventUtil.marshalMouseEventMap[type];
			if (actualType)
			{
				addEventListenerToSandboxes(type, sandboxMouseListener, useCapture, priority, useWeakReference);
				super.addEventListener(type, listener, useCapture, priority, useWeakReference);
				return;
			}
		}
		
		// When the first listener registers for 'idle' events,
		// create a Timer that will fire every IDLE_INTERVAL.
		if (type == FlexEvent.IDLE && !idleTimer)
		{
			idleTimer = new Timer(IDLE_INTERVAL);
			idleTimer.addEventListener(TimerEvent.TIMER,
									   idleTimer_timerHandler);
			idleTimer.start();

			// Make sure we get all activity
			// in case someone calls stopPropagation().
			addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler, true);
			addEventListener(MouseEvent.MOUSE_UP, mouseUpHandler, true);
		}

		super.addEventListener(type, listener, useCapture, priority, useWeakReference);
	}

	/**
	 *  @private
	 * 
	 * Test if this system manager has any sandbox bridges.
	 * 
	 * @return true if there are sandbox bridges, false otherwise.
	 */
	private function hasSandboxBridges():Boolean
	{
		if (sandboxBridgeGroup)
			return true;
		
		return false;
	}
	
	/**
	 *  @private
	 */
	override public function removeEventListener(type:String, listener:Function,
												 useCapture:Boolean = false):void
	{
		// These two events will dispatched to applications in sandboxes.
		if (type == FlexEvent.RENDER || type == FlexEvent.ENTER_FRAME)
		{
			if (type == FlexEvent.RENDER)
				type = Event.RENDER;
			else
				type = Event.ENTER_FRAME;
				
			try
			{
				if (stage)
					stage.removeEventListener(type, listener, useCapture);
				else
					super.removeEventListener(type, listener, useCapture);
			}
			catch (error:SecurityError)
			{
				super.removeEventListener(type, listener, useCapture);
			}
		
			return;
		}

		if (type == MouseEvent.MOUSE_MOVE || type == MouseEvent.MOUSE_UP || type == MouseEvent.MOUSE_DOWN 
				|| type == Event.ACTIVATE || type == Event.DEACTIVATE)
		{
			// also listen to stage if allowed
			try
			{
				if (stage)
				{
					var newListener:StageEventProxy = weakReferenceProxies[listener];
					if (!newListener)
					{
						newListener = strongReferenceProxies[listener];
						if (newListener)
							delete strongReferenceProxies[listener];
					}
					if (newListener)
						stage.removeEventListener(type, newListener.stageListener, false);
				}
			}
			catch (error:SecurityError)
			{
			}
		}

		if (hasSandboxBridges())
		{
			var actualType:String = EventUtil.marshalMouseEventMap[type];
			if (actualType)
			{
				removeEventListenerFromSandboxes(type, sandboxMouseListener, useCapture);
				super.removeEventListener(type, listener, useCapture);
				return;
			}
		}
		
		// When the last listener unregisters for 'idle' events,
		// stop and release the Timer.
		if (type == FlexEvent.IDLE)
		{
			super.removeEventListener(type, listener, useCapture);

			if (!hasEventListener(FlexEvent.IDLE) && idleTimer)
			{
				idleTimer.stop();
				idleTimer = null;

				removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
				removeEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
			}
		}
		else
		{
			super.removeEventListener(type, listener, useCapture);
		}
	}

	//--------------------------------------------------------------------------
	//
	//  Overridden methods: DisplayObjectContainer
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	override public function addChild(child:DisplayObject):DisplayObject
	{
		// Adjust the partition indexes
		// before the "added" event is dispatched.
		noTopMostIndex++;

		return rawChildren_addChildAt(child, noTopMostIndex - 1);
	}

	/**
	 *  @private
	 */
	override public function addChildAt(child:DisplayObject,
										index:int):DisplayObject
	{
		// Adjust the partition indexes
		// before the "added" event is dispatched.
		noTopMostIndex++;

		return rawChildren_addChildAt(child, applicationIndex + index);
	}

	/**
	 *  @private
	 * 
	 * Used by SystemManagerProxy to add a mouse catcher as a child.
	 */ 
	mx_internal final function $addChildAt(child:DisplayObject,
										index:int):DisplayObject
	{
		return super.addChildAt(child, index);
	}

	/**
	 *  @private
	 * 
	 *  Companion to $addChildAt.
	 */
	mx_internal final function $removeChildAt(index:int):DisplayObject
	{
		return super.removeChildAt(index);
	}


	/**
	 *  @private
	 */
	override public function removeChild(child:DisplayObject):DisplayObject
	{
		// Adjust the partition indexes
		// before the "removed" event is dispatched.
		noTopMostIndex--;

		return rawChildren_removeChild(child);
	}

	/**
	 *  @private
	 */
	override public function removeChildAt(index:int):DisplayObject
	{
		// Adjust the partition indexes
		// before the "removed" event is dispatched.
		noTopMostIndex--;

		return rawChildren_removeChildAt(applicationIndex + index);
	}

	/**
	 *  @private
	 */
  	override public function getChildAt(index:int):DisplayObject
	{
		return super.getChildAt(applicationIndex + index)
	}

	/**
	 *  @private
	 */
  	override public function getChildByName(name:String):DisplayObject
  	{
		return super.getChildByName(name);
  	}

	/**
	 *  @private
	 */
  	override public function getChildIndex(child:DisplayObject):int
	{
		return super.getChildIndex(child) - applicationIndex;
	}

	/**
	 *  @private
	 */
	override public function setChildIndex(child:DisplayObject, newIndex:int):void
	{
		super.setChildIndex(child, applicationIndex + newIndex)
	}

	/**
	 *  @private
	 */
	override public function getObjectsUnderPoint(point:Point):Array
	{
		var children:Array = [];

		// Get all the children that aren't tooltips and cursors.
		var n:int = topMostIndex;
		for (var i:int = 0; i < n; i++)
		{
			var child:DisplayObject = super.getChildAt(i);
			if (child is DisplayObjectContainer)
			{
				var temp:Array =
					DisplayObjectContainer(child).getObjectsUnderPoint(point);

				if (temp)
					children = children.concat(temp);
			}
		}

		return children;
	}

	/**
	 *  @private
	 */
	override public function contains(child:DisplayObject):Boolean
	{
		if (super.contains(child))
		{
			if (child.parent == this)
			{
				var childIndex:int = super.getChildIndex(child);
				if (childIndex < noTopMostIndex)
					return true;
			}
			else
			{
				for (var i:int = 0; i < noTopMostIndex; i++)
				{
					var myChild:DisplayObject = super.getChildAt(i);
					if (myChild is IRawChildrenContainer)
					{
						if (IRawChildrenContainer(myChild).rawChildren.contains(child))
							return true;
					}
					if (myChild is DisplayObjectContainer)
					{
						if (DisplayObjectContainer(myChild).contains(child))
							return true;
					}
				}
			}
		}
		return false;
	}

	//--------------------------------------------------------------------------
	//
	//  Methods: Initialization
	//
	//--------------------------------------------------------------------------

	/**
	 *   A factory method that requests an instance of a
	 *  definition known to the module.
	 * 
	 *  You can provide an optional set of parameters to let building
	 *  factories change what they create based on the
	 *  input. Passing null indicates that the default definition
	 *  is created, if possible. 
	 *
	 *  This method is overridden in the autogenerated subclass.
	 *
	 * @param params An optional list of arguments. You can pass
	 *  any number of arguments, which are then stored in an Array
	 *  called <code>parameters</code>. 
	 *
	 * @return An instance of the module, or <code>null</code>.
	 */
	public function create(... params):Object
	{
	    var mainClassName:String = info()["mainClassName"];

		if (mainClassName == null)
	    {
            var url:String = loaderInfo.loaderURL;
            var dot:int = url.lastIndexOf(".");
            var slash:int = url.lastIndexOf("/");
            mainClassName = url.substring(slash + 1, dot);
	    }

		var mainClass:Class = Class(getDefinitionByName(mainClassName));
		
		return mainClass ? new mainClass() : null;
	}

	/**
	 *  @private
	 *  Creates an instance of the preloader, adds it as a child, and runs it.
	 *  This is needed by FlexBuilder. Do not modify this function.
	 */
	mx_internal function initialize():void
	{
		if (isStageRoot)
		{
			_width = stage.stageWidth;
			_height = stage.stageHeight;
		}
		else
		{
			_width = loaderInfo.width;
			_height = loaderInfo.height;
		}

		// Create an instance of the preloader and add it to the stage
		preloader = new Preloader();

		// Listen for preloader events
		// Once the preloader dispatches initStart, then create the application instance
		preloader.addEventListener(FlexEvent.INIT_PROGRESS,
								   preloader_initProgressHandler);
		preloader.addEventListener(FlexEvent.PRELOADER_DONE,
								   preloader_preloaderDoneHandler);

		// Add the preloader as a child.  Use backing variable because when loaded
		// we redirect public API to parent systemmanager
		if (!_popUpChildren)
		{
			_popUpChildren = new SystemChildrenList(
				this, new QName(mx_internal, "noTopMostIndex"), new QName(mx_internal, "topMostIndex"));
		}
		_popUpChildren.addChild(preloader);

		var rsls:Array = info()["rsls"];
		var cdRsls:Array = info()["cdRsls"];
		var usePreloader:Boolean = true;
        if (info()["usePreloader"] != undefined)
            usePreloader = info()["usePreloader"];

		var preloaderDisplayClass:Class = info()["preloader"] as Class;
        if (usePreloader && !preloaderDisplayClass)
            preloaderDisplayClass = DownloadProgressBar;

        // Put cross-domain RSL information in the RSL list.
        var rslList:Array = [];
        var n:int;
        var i:int;
		if (cdRsls && cdRsls.length > 0)
		{
			var crossDomainRSLItem:Class = Class(getDefinitionByName("mx.core::CrossDomainRSLItem"));
			n = cdRsls.length;
			for (i = 0; i < n; i++)
			{
				// If crossDomainRSLItem is null, then this is a compiler error. It should not be null.
				var cdNode:Object = new crossDomainRSLItem(cdRsls[i]["rsls"],
													cdRsls[i]["policyFiles"],
													cdRsls[i]["digests"],
													cdRsls[i]["types"],
													cdRsls[i]["isSigned"]);
				rslList.push(cdNode);				
			}
		}

		// Append RSL information in the RSL list.
		if (rsls != null && rsls.length > 0)
		{
			n = rsls.length;
			for (i = 0; i < n; i++)
			{
			    var node:RSLItem = new RSLItem(rsls[i].url);
				rslList.push(node);
			}
		}

		// Register the ResourceManager class with Singleton early
		// so that we can use the ResourceManager in frame 1.
		// Same with EmbfeddedFontRegistry and StyleManager
		// The other managers get registered with Singleton later,
		// in frame 2, by docFrameHandler().
		Singleton.registerClass("mx.resources::IResourceManager",
			Class(getDefinitionByName("mx.resources::ResourceManagerImpl")));
		var resourceManager:IResourceManager = ResourceManager.getInstance();

		var fontRegistry:EmbeddedFontRegistry;	// link in the EmbeddedFontRegistry Class			
		Singleton.registerClass("mx.core::IEmbeddedFontRegistry",
				Class(getDefinitionByName("mx.core::EmbeddedFontRegistry")));
				
		Singleton.registerClass("mx.styles::IStyleManager",
			Class(getDefinitionByName("mx.styles::StyleManagerImpl")));

		Singleton.registerClass("mx.styles::IStyleManager2",
			Class(getDefinitionByName("mx.styles::StyleManagerImpl")));


		// The FlashVars of the SWF's HTML wrapper,
		// or the query parameters of the SWF URL,
		// can specify the ResourceManager's localeChain.
		var localeChainList:String =  
			loaderInfo.parameters["localeChain"];
		if (localeChainList != null && localeChainList != "")
			resourceManager.localeChain = localeChainList.split(",");

		// They can also specify a comma-separated list of URLs
		// for resource modules to be preloaded during frame 1.
		var resourceModuleURLList:String =
			loaderInfo.parameters["resourceModuleURLs"];
		var resourceModuleURLs:Array =
			resourceModuleURLList ? resourceModuleURLList.split(",") : null;

		// Initialize the preloader.
		preloader.initialize(
			usePreloader,
			preloaderDisplayClass,
			preloaderBackgroundColor,
			preloaderBackgroundAlpha,
			preloaderBackgroundImage,
			preloaderBackgroundSize,
			isStageRoot ? stage.stageWidth : loaderInfo.width,
			isStageRoot ? stage.stageHeight : loaderInfo.height,
		    null,
			null,
			rslList,
			resourceModuleURLs);
	}

	/**
	 *  @private
	 *  When this is called, we execute all callbacks queued up to this point.
	 */
	private function executeCallbacks():void
	{
		// temporary workaround for player bug.  The root class should always
		// be parented or we need some other way to determine
		// our application domain
		if (!parent && canAccessParent())
			return;

		while (initCallbackFunctions.length > 0)
		{
			var initFunction:Function = initCallbackFunctions.shift();
			initFunction(this);
		}
	}

	//--------------------------------------------------------------------------
	//
	//  Methods: Child management
	//
	//--------------------------------------------------------------------------

	/**
     *  @private
     */
	mx_internal function addingChild(child:DisplayObject):void
	{
		var newNestLevel:int = 1;
		
		// non-top level system managers may not be able to reference their parent if
		// they are a proxy for popups.
		if (!topLevel && parent)
		{
			// non-topLevel SystemManagers are buried by Flash.display.Loader and
			// other non-framework layers so we have to figure out the nestlevel
			// by searching up the parent chain.
			var obj:DisplayObjectContainer = parent.parent;
			while (obj)
			{
				if (obj is ILayoutManagerClient)
				{
					newNestLevel = ILayoutManagerClient(obj).nestLevel + 1;
					break;
				}
				obj = obj.parent;
			}
		}
		nestLevel = newNestLevel;

		if (child is IUIComponent)
			IUIComponent(child).systemManager = this;

		// Local variables for certain classes we need to check against below.
		// This is the backdoor way around linking in the class in question.
		var uiComponentClassName:Class =
			Class(getDefinitionByName("mx.core.UIComponent"));

		// If the document property isn't already set on the child,
		// set it to be the same as this component's document.
		// The document setter will recursively set it on any
		// descendants of the child that exist.
		if (child is IUIComponent &&
			!IUIComponent(child).document)
		{
			IUIComponent(child).document = document;
		}

		// Set the nestLevel of the child to be one greater
		// than the nestLevel of this component.
		// The nestLevel setter will recursively set it on any
		// descendants of the child that exist.
		if (child is ILayoutManagerClient)
        	ILayoutManagerClient(child).nestLevel = nestLevel + 1;

		if (child is InteractiveObject)
			if (doubleClickEnabled)
				InteractiveObject(child).doubleClickEnabled = true;

		if (child is IUIComponent)
			IUIComponent(child).parentChanged(this);

		// Sets up the inheritingStyles and nonInheritingStyles objects
		// and their proto chains so that getStyle() works.
		// If this object already has some children,
		// then reinitialize the children's proto chains.
        if (child is IStyleClient)
			IStyleClient(child).regenerateStyleCache(true);

		if (child is ISimpleStyleClient)
			ISimpleStyleClient(child).styleChanged(null);

        if (child is IStyleClient)
			IStyleClient(child).notifyStyleChangeInChildren(null, true);

		// Need to check to see if the child is an UIComponent
		// without actually linking in the UIComponent class.
		if (uiComponentClassName && child is uiComponentClassName)
			uiComponentClassName(child).initThemeColor();

		// Inform the component that it's style properties
		// have been fully initialized. Most components won't care,
		// but some need to react to even this early change.
		if (uiComponentClassName && child is uiComponentClassName)
			uiComponentClassName(child).stylesInitialized();
	}

	/**
	 *  @private
	 */
	mx_internal function childAdded(child:DisplayObject):void
	{
		child.dispatchEvent(new FlexEvent(FlexEvent.ADD));

		if (child is IUIComponent)
			IUIComponent(child).initialize(); // calls child.createChildren()
	}

	/**
     *  @private
     */
	mx_internal function removingChild(child:DisplayObject):void
	{
		child.dispatchEvent(new FlexEvent(FlexEvent.REMOVE));
	}

	/**
     *  @private
     */
	mx_internal function childRemoved(child:DisplayObject):void
	{
		if (child is IUIComponent)
			IUIComponent(child).parentChanged(null);
	}

	//--------------------------------------------------------------------------
	//
	//  Methods: Support for rawChildren access
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	mx_internal function rawChildren_addChild(child:DisplayObject):DisplayObject
	{
		addingChild(child);

		super.addChild(child);

		childAdded(child); // calls child.createChildren()

		return child;
	}

	/**
	 *  @private
	 */
	mx_internal function rawChildren_addChildAt(child:DisplayObject,
												index:int):DisplayObject
	{
		addingChild(child);

		super.addChildAt(child, index);

		childAdded(child); // calls child.createChildren()

		return child;
	}

	/**
	 *  @private
	 */
	mx_internal function rawChildren_removeChild(child:DisplayObject):DisplayObject
	{
		removingChild(child);
		super.removeChild(child);
		childRemoved(child);

		return child;
	}

	/**
	 *  @private
	 */
	mx_internal function rawChildren_removeChildAt(index:int):DisplayObject
	{
		var child:DisplayObject = super.getChildAt(index);

		removingChild(child);

		super.removeChildAt(index);

		childRemoved(child);

		return child;
	}

	/**
	 *  @private
	 */
  	mx_internal function rawChildren_getChildAt(index:int):DisplayObject
	{
		return super.getChildAt(index);
	}

	/**
	 *  @private
	 */
  	mx_internal function rawChildren_getChildByName(name:String):DisplayObject
  	{
		return super.getChildByName(name);
  	}

	/**
	 *  @private
	 */
  	mx_internal function rawChildren_getChildIndex(child:DisplayObject):int
	{
		return super.getChildIndex(child);
	}

	/**
	 *  @private
	 */
	mx_internal function rawChildren_setChildIndex(child:DisplayObject, newIndex:int):void
	{
		super.setChildIndex(child, newIndex);
	}

	/**
	 *  @private
	 */
	mx_internal function rawChildren_getObjectsUnderPoint(pt:Point):Array
	{
		return super.getObjectsUnderPoint(pt);
	}

	/**
	 *  @private
	 */
	mx_internal function rawChildren_contains(child:DisplayObject):Boolean
	{
		return super.contains(child);
	}

	//--------------------------------------------------------------------------
	//
	//  Methods: Measurement and Layout
	//
	//--------------------------------------------------------------------------

    /**
     *  A convenience method for determining whether to use the
	 *  explicit or measured width.
	 *
     *  @return A Number which is the <code>explicitWidth</code> if defined,
	 *  or the <code>measuredWidth</code> property if not.
     */
    public function getExplicitOrMeasuredWidth():Number
    {
		return !isNaN(explicitWidth) ? explicitWidth : measuredWidth;
    }

    /**
     *  A convenience method for determining whether to use the
	 *  explicit or measured height.
	 *
     *  @return A Number which is the <code>explicitHeight</code> if defined,
	 *  or the <code>measuredHeight</code> property if not.
     */
    public function getExplicitOrMeasuredHeight():Number
    {
		return !isNaN(explicitHeight) ? explicitHeight : measuredHeight;
    }

	/**
	 *  Calling the <code>move()</code> method
	 *  has no effect as it is directly mapped
	 *  to the application window or the loader.
	 *
	 *  @param x The new x coordinate.
	 *
	 *  @param y The new y coordinate.
	 */
	public function move(x:Number, y:Number):void
	{
	}

	/**
	 *  Calling the <code>setActualSize()</code> method
	 *  has no effect if it is directly mapped
	 *  to the application window and if it is the top-level window.
	 *  Otherwise attempts to resize itself, clipping children if needed.
	 *
	 *  @param newWidth The new width.
	 *
	 *  @param newHeight The new height.
	 */
	public function setActualSize(newWidth:Number, newHeight:Number):void
	{
		if (isStageRoot) return;

		_width = newWidth;
		_height = newHeight;

		// mouseCatcher is a mask if not stage root
		if (mouseCatcher)
		{
			mouseCatcher.width = newWidth;
			mouseCatcher.height = newHeight;
		}

		dispatchEvent(new Event(Event.RESIZE));
	}

	//--------------------------------------------------------------------------
	//
	//  Methods: Styles
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Call regenerateStyleCache() on all children of this SystemManager.
	 *  If the recursive parameter is true, continue doing this
	 *  for all descendants of these children.
	 */
	mx_internal function regenerateStyleCache(recursive:Boolean):void
	{
		var foundTopLevelWindow:Boolean = false;

		var n:int = rawChildren.numChildren;
		for (var i:int = 0; i < n; i++)
		{
			var child:IStyleClient =
				rawChildren.getChildAt(i) as IStyleClient;

			if (child)
				child.regenerateStyleCache(recursive);

			if (isTopLevelWindow(DisplayObject(child)))
				foundTopLevelWindow = true;

			// Refetch numChildren because notifyStyleChangedInChildren()
			// can add/delete a child and therefore change numChildren.
			n = rawChildren.numChildren;
		}

		// During startup the top level window isn't added
		// to the child list until late into the startup sequence.
		// Make sure we call regenerateStyleCache()
		// on the top level window even if it isn't a child yet.
		if (!foundTopLevelWindow && topLevelWindow is IStyleClient)
			IStyleClient(topLevelWindow).regenerateStyleCache(recursive);
	}

	/**
	 *  @private
	 *  Call styleChanged() and notifyStyleChangeInChildren()
	 *  on all children of this SystemManager.
	 *  If the recursive parameter is true, continue doing this
	 *  for all descendants of these children.
	 */
	mx_internal function notifyStyleChangeInChildren(styleProp:String,
													 recursive:Boolean):void
	{
		var foundTopLevelWindow:Boolean = false;

		var n:int = rawChildren.numChildren;
		for (var i:int = 0; i < n; i++)
		{
			var child:IStyleClient =
				rawChildren.getChildAt(i) as IStyleClient;

			if (child)
			{
				child.styleChanged(styleProp);
				child.notifyStyleChangeInChildren(styleProp, recursive);
			}

			if (isTopLevelWindow(DisplayObject(child)))
				foundTopLevelWindow = true;

			// Refetch numChildren because notifyStyleChangedInChildren()
			// can add/delete a child and therefore change numChildren.
			n = rawChildren.numChildren;
		}

		// During startup the top level window isn't added
		// to the child list until late into the startup sequence.
		// Make sure we call notifyStyleChangeInChildren()
		// on the top level window even if it isn't a child yet.
		if (!foundTopLevelWindow && topLevelWindow is IStyleClient)
		{
			IStyleClient(topLevelWindow).styleChanged(styleProp);
			IStyleClient(topLevelWindow).notifyStyleChangeInChildren(
				styleProp, recursive);
		}
	}


	//--------------------------------------------------------------------------
	//
	//  Methods: Focus
	//
	//--------------------------------------------------------------------------

	/**
	 *  @inheritDoc
	 */
	public function activate(f:IFocusManagerContainer):void
	{
		activateForm(f);
	}

	/**
	 * @private
	 * 
	 * New version of activate that does not require a
	 * IFocusManagerContainer.
	 */
	private function activateForm(f:Object):void
	{

		// trace("SM: activate " + f + " " + forms.length);
		if (form)
		{
			if (form != f && forms.length > 1)
			{
				// Switch the active form.
				if (isRemotePopUp(form))
				{
					if (!areRemotePopUpsEqual(form, f))
						deactivateRemotePopUp(form);													
				}
				else
				{
					var z:IFocusManagerContainer = IFocusManagerContainer(form);
				// trace("OLW " + f + " deactivating old form " + z);
				z.focusManager.deactivate();
			}
		}
		}

		form = f;

		// trace("f = " + f);
		if (isRemotePopUp(f))
		{
			activateRemotePopUp(f);
		}
		else if (f.focusManager)
		{
			// trace("has focus manager");
			f.focusManager.activate();
		}

		updateLastActiveForm();

		// trace("END SM: activate " + f);
	}

	/**
	 *  @inheritDoc
	 */
	public function deactivate(f:IFocusManagerContainer):void
	{
		deactivateForm(Object(f));
	}
	
	/**
	 * @private
	 * 
	 * New version of deactivate that works with remote pop ups.
	 * 
	 */
	private function deactivateForm(f:Object):void
	{
		// trace(">>SM: deactivate " + f);

		if (form)
		{
			// If there's more than one form and this is it, find a new form.
			if (form == f && forms.length > 1)
			{
				if (isRemotePopUp(form))
					deactivateRemotePopUp(form);
				else
				form.focusManager.deactivate();

				form = findLastActiveForm(f);
				
				// make sure we have a valid top level window.
				// This can be null if top level window has been hidden for some reason.
				if (form)
				{
					if (isRemotePopUp(form))
						activateRemotePopUp(form);					
					else 
						form.focusManager.activate();
				}
			}
		}

		// trace("<<SM: deactivate " + f);
	}


	/**
	 * @private
	 * 
	 * @param f form being deactivated
	 * 
	 * @return the next form to activate, excluding the form being deactivated.
	 */
	private function findLastActiveForm(f:Object):Object
	{
		var n:int = forms.length;
		for (var i:int = forms.length - 1; i >= 0; i--)
		{
			// Verify the form is visible and enabled
			if (forms[i] != f && canActivatePopUp(forms[i]))
				return forms[i];
		}
		
		throw new Error();  // shouldn't get here		
	}
	
	
	/**
	 * @private
	 * 
	 * @return true if the form can be activated, false otherwise.
	 */
	 private function canActivatePopUp(f:Object):Boolean
	 {
	 	if (isRemotePopUp(f))
	 	{
	 		var remotePopUp:RemotePopUp = RemotePopUp(f);
			var event:SandboxBridgeEvent = new SandboxBridgeEvent(SandboxBridgeRequest.CAN_ACTIVATE, 
																  false, true, null,
																  remotePopUp.window);
			return !IEventDispatcher(remotePopUp.bridge).dispatchEvent(event);
	 	}
	 	else if (canActivateLocalComponent(f))
			return true;
			
		return false;
	 }
	 
	 
	 /**
	 * @private
	 * 
	 * Test is a local component can be activated.
	 */
	 private function canActivateLocalComponent(o:Object):Boolean
	 {
	 	
	 	if (o is Sprite && o is IUIComponent &&
	 	    Sprite(o).visible && IUIComponent(o).enabled)
			return true;
			
		return false;
	 }
	 
	/**
	 * @private
	 * 
	 * @return true if the form is a RemotePopUp, false if the form is IFocusManagerContainer.
	 *
	 */
	private static function isRemotePopUp(form:Object):Boolean
	{
		return !(form is IFocusManagerContainer);
	}

	/**
	 * @private
	 * 
	 * @return true if form1 and form2 are both of type RemotePopUp and are equal, false otherwise.
	 */
	private static function areRemotePopUpsEqual(form1:Object, form2:Object):Boolean
	{
		if (!(form1 is RemotePopUp))
			return false;
		
		if (!(form2 is RemotePopUp))
			return false;
		
		var remotePopUp1:RemotePopUp = RemotePopUp(form1);
		var remotePopUp2:RemotePopUp = RemotePopUp(form2);
		
		if (remotePopUp1.window == remotePopUp2.window && 
		    remotePopUp1.bridge && remotePopUp2.bridge)
			return true;
		
		return false;
	}


	/**
	 * @private
	 * 
	 * Find a remote form that is hosted by this system manager.
	 * 
	 * @param window unique id of popUp within a bridged application
	 * @param bridge bridge of owning application.
	 * 
	 * @return RemotePopUp if hosted by this system manager, false otherwise.
	 */
	private function findRemotePopUp(window:Object, bridge:IEventDispatcher):RemotePopUp
	{
        // remove the placeholder from forms array
				var n:int = forms.length;
				for (var i:int = 0; i < n; i++)
				{
			if (isRemotePopUp(forms[i]))
			{
				var popUp:RemotePopUp = RemotePopUp(forms[i]);
				if (popUp.window == window && 
				    popUp.bridge == bridge)
				    return popUp;
			}
		}
		
		return null;
	}
	
	/**
	 * Remote a remote form from the forms array.
	 * 
	 * form Locally created remote form.
	 */
	private function removeRemotePopUp(form:RemotePopUp):void
					{
	    // remove popup from forms array
		var n:int = forms.length;
		for (var i:int = 0; i < n; i++)
		{
			if (isRemotePopUp(forms[i]))
			{
				if (forms[i].window == form.window)
						{
					if (forms[i] == form)
						deactivateForm(form);
					forms.splice(i, 1);
					break;
				}
			}
						}
					}

	/**
	 * @private
	 * 
	 * Activate a form that belongs to a system manager in another
	 * sandbox or peer application domain.
	 * 
	 * @param form	a RemotePopUp object.
	 * */ 
	private function activateRemotePopUp(form:Object):void
					{
		var request:SandboxBridgeRequest = new SandboxBridgeRequest(SandboxBridgeRequest.ACTIVATE, 
																	false, false,
																	form.bridge,
																	form.window);
		var bridge:Object = form.bridge;
		if (bridge)
			bridge.dispatchEvent(request);
					}
	
	
	private function deactivateRemotePopUp(form:Object):void
	{
		var request:SandboxBridgeRequest = new SandboxBridgeRequest(SandboxBridgeRequest.DEACTIVATE,
																	false, false,
																	form.bridge,
																	form.window);
		var bridge:Object = form.bridge;
		if (bridge)
			bridge.dispatchEvent(request);
				}

	/**
	 * Test if two forms are equal.
	 * 
	 * @param form1 - may be of type a DisplayObjectContainer or a RemotePopUp
	 * @param form2 - may be of type a DisplayObjectContainer or a RemotePopUp
	 * 
	 * @return true if the forms are equal, false otherwise.
	 */
	private function areFormsEqual(form1:Object, form2:Object):Boolean
	{
		if (form1 == form2)
			return true;
			
		// if the forms are both remote forms, then compare them, otherwise
		// return false.
		if (form1 is RemotePopUp && form2 is RemotePopUp)
		{
			return areRemotePopUpsEqual(form1, form2);	
		}

		return false;
	}

	/**
	 *  @inheritDoc
	 */
	public function addFocusManager(f:IFocusManagerContainer):void
	{
		// trace("OLW: add focus manager" + f);

		forms.push(f);

		// trace("END OLW: add focus manager" + f);
	}

	/**
	 *  @inheritDoc
	 */
	public function removeFocusManager(f:IFocusManagerContainer):void
	{
		// trace("OLW: remove focus manager" + f);

		var n:int = forms.length;
		for (var i:int = 0; i < n; i++)
		{
			if (forms[i] == f)
			{
				if (form == f)
					deactivate(f);

				// If this is a bridged application, send a message to the parent
				// to let them know the form has been deactivated so they can
				// activate a new form.
				fireDeactivatedWindowEvent(DisplayObject(f));
				
				forms.splice(i, 1);
				
				// trace("END OLW: successful remove focus manager" + f);
				return;
			}
		}

		// trace("END OLW: remove focus manager" + f);
	}

	//--------------------------------------------------------------------------
	//
	//  Methods: IParentAccess
	//
	//--------------------------------------------------------------------------
	
	/**
	 * @inheritdoc
	 */
	public function canAccessParent():Boolean
	{
		try
		{
			return loaderInfo.parentAllowsChild;
		}
		catch (error:Error)
		{
			//Error #2099: The loading object is not sufficiently loaded to provide this information.
		}
		
		return false;	// assume the worst
	}

	/**
	 * @inheritdoc
	 */
	public function accessibleFromParent():Boolean
	{
		try
		{
			return loaderInfo.childAllowsParent;
		}
		catch (error:Error)
		{
			//Error #2099: The loading object is not sufficiently loaded to provide this information.
		}
		
		return false;	// assume the worst
	}



	//--------------------------------------------------------------------------
	//
	//  Methods: Other
	//
	//--------------------------------------------------------------------------

	/**
	 *  @inheritDoc
	 */
	public function getDefinitionByName(name:String):Object
	{
		var domain:ApplicationDomain =
			!topLevel && parent is Loader ?
			Loader(parent).contentLoaderInfo.applicationDomain :
            info()["currentDomain"] as ApplicationDomain;

		//trace("SysMgr.getDefinitionByName domain",domain,"currentDomain",info()["currentDomain"]);	
			
        var definition:Object;

        if (domain.hasDefinition(name))
		{
			definition = domain.getDefinition(name);
			//trace("SysMgr.getDefinitionByName got definition",definition,"name",name);
		}

		return definition;
	}

	/**
	 *  Returns the root DisplayObject of the SWF that contains the code
	 *  for the given object.
	 *
	 *  @param object Any Object. 
	 * 
	 *  @return The root DisplayObject
	 */
	public static function getSWFRoot(object:Object):DisplayObject
	{
		var className:String = getQualifiedClassName(object);

		for (var p:* in allSystemManagers)
		{
			var sm:ISystemManager = p as ISystemManager;
			var domain:ApplicationDomain = sm.loaderInfo.applicationDomain;
			try
			{
				var cls:Class = Class(domain.getDefinition(className));
				if (object is cls)
					return sm as DisplayObject;
			}
			catch(e:Error)
			{
			}
		}
		return null;
	}
	
	/**
	 *  @inheritDoc
	 */
	public function isTopLevel():Boolean
	{
		return topLevel;
	}

	/**
	 * @inheritdoc
	 */	
	public function isTopLevelRoot():Boolean
	{
		return isStageRoot || isBootstrapRoot;
	}
	
	/**
	 *  Returns <code>true</code> if the given DisplayObject is the 
	 *  top-level window.
	 *
	 *  @param object The DisplayObject to test.
	 *
	 *  @return <code>true</code> if the given DisplayObject is the 
	 *  top-level window.
	 */
	public function isTopLevelWindow(object:DisplayObject):Boolean
	{
		return object is IUIComponent &&
			   IUIComponent(object) == topLevelWindow;
	}

	/**
	 *  @inheritDoc
	 */
    public function isFontFaceEmbedded(textFormat:TextFormat):Boolean
    {
        var fontName:String = textFormat.font;

        var fl:Array = Font.enumerateFonts();
        for (var f:int = 0; f < fl.length; ++f)
        {
            var font:Font = Font(fl[f]);
            if (font.fontName == fontName)
            {
                var style:String = "regular";
                if (textFormat.bold && textFormat.italic)
                    style = "boldItalic";
                else if (textFormat.bold)
                    style = "bold";
                else if (textFormat.italic)
                    style = "italic";

                if (font.fontStyle == style)
                    return true;
            }
        }

		if (!fontName ||
			!embeddedFontList ||
			!embeddedFontList[fontName])
        {
            return false;
        }

        var info:Object = embeddedFontList[fontName];

		return !((textFormat.bold && !info.bold) ||
				 (textFormat.italic && !info.italic) ||
				 (!textFormat.bold && !textFormat.italic &&
				 !info.regular));
    }

    /**
     *  @private
     *  
     *  Dispatch an invalidate request to invalidate the size and
     *  display list of the parent application.
     */     
    private function dispatchInvalidateRequest():void
    {
        var bridge:IEventDispatcher = sandboxBridgeGroup.parentBridge;
        var request:SandboxBridgeRequest = new SandboxBridgeRequest(
                                                    SandboxBridgeRequest.INVALIDATE,
                                                    false, false,
                                                    bridge,
                                                    SandboxBridgeRequest.INVALIDATE_SIZE |
                                                    SandboxBridgeRequest.INVALIDATE_DISPLAY_LIST);
         bridge.dispatchEvent(request);
    }
    
	/**
	 *  @private
	 *  Makes the mouseCatcher the same size as the stage,
	 *  filling it with transparent pixels.
	 */
	// VERSION_SKEW change from private to mx_internal so it can be called by SystemManagerProxy
	mx_internal function resizeMouseCatcher():void
	{
		if (mouseCatcher)
		{
			// VERSION_SKEW
			try
			{
			var g:Graphics = mouseCatcher.graphics;
			var s:Rectangle = screen;
			g.clear();
			g.beginFill(0x000000, 0);
			g.drawRect(0, 0, s.width, s.height);
			g.endFill();
				
			}
			catch (e:SecurityError)
			{
				// trace("resizeMouseCatcher: ignoring security error " + e);
			}
		}
	}

	//--------------------------------------------------------------------------
	//
	//  Event handlers
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	private function initHandler(event:Event):void
	{
		// we can still be the top level root if we can access our
		// parent and get a positive response to the query
		if (!isStageRoot)
		{
			if (root.loaderInfo.parentAllowsChild)
			{
				try
				{
					if (!parent.dispatchEvent(new Event("mx.managers.SystemManager.isBootstrapRoot", false, true)))
						isBootstrapRoot = true;
				}
				catch (e:Error)
				{
				}
			}
		}

		allSystemManagers[this] = this.loaderInfo.url;
	    root.loaderInfo.removeEventListener(Event.INIT, initHandler);

		if (useBridge())
		{
			// create a bridge so we can talk to our parent.
			sandboxBridgeGroup = new SandboxBridgeGroup(this);
			sandboxBridgeGroup.parentBridge = loaderInfo.sharedEvents;
			addParentBridgeListeners();

			// send message to parent that we are ready.
			// pass up the sandbox bridge to the parent so its knows who we are.
			var bridgeEvent:SandboxBridgeEvent = new SandboxBridgeEvent(SandboxBridgeEvent.NEW_BRIDGED_APPLICATION);
			bridgeEvent.data = sandboxBridgeGroup.parentBridge;
			
			sandboxBridgeGroup.parentBridge.dispatchEvent(bridgeEvent);

			// placeholder popups are started locally
			addEventListener(PopUpRequest.ADD_PLACEHOLDER, addPlaceholderPopupRequestHandler);
		}

		// every SM has to have this listener in case it is the SM for some child AD that contains a manager
		// and the parent ADs don't have that manager.
		getSandboxRoot().addEventListener(MarshalEvent.INIT_MANAGER, initManagerHandler, false, 0, true);
		// once managers get initialized, they bounce things off the sandbox root
		if (getSandboxRoot() == this)
		{
			addEventListener(MarshalEvent.SYSTEM_MANAGER, systemManagerHandler, false, 0, true);
			addEventListener(MarshalEvent.MARSHAL, marshalHandler, false, 0, true);

			addEventListener(PopUpRequest.ADD_PLACEHOLDER, addPlaceholderPopupRequestHandler);
			addEventListener(PopUpRequest.REMOVE_PLACEHOLDER, removePlaceholderPopupRequestHandler);
			addEventListener(SandboxBridgeEvent.ACTIVATE_WINDOW, activateFormSandboxEventHandler);
			addEventListener(SandboxBridgeEvent.DEACTIVATE_WINDOW, deactivateFormSandboxEventHandler); 
		}

	    var docFrame:int = (totalFrames == 1)? 0 : 1;

        addFrameScript(docFrame, docFrameHandler);
	    for (var f:int = docFrame + 1; f < totalFrames; ++f)
	    {
		    addFrameScript(f, extraFrameHandler);
		}

	    initialize();
	    
	}

	/**
	 *  @private
	 *  Once the swf has been fully downloaded,
	 *  advance the playhead to the next frame.
	 *  This will cause the framescript to run, which runs frameEndHandler().
	 */
	private function preloader_initProgressHandler(event:Event):void
	{
		// Advance the next frame
		preloader.removeEventListener(FlexEvent.INIT_PROGRESS,
									  preloader_initProgressHandler);

        deferredNextFrame();
	}

	/**
	 *  @private
	 *  Remove the preloader and add the application as a child.
	 */
	private function preloader_preloaderDoneHandler(event:Event):void
	{
		var app:IUIComponent = topLevelWindow;

		// Once the preloader dispatches the PRELOADER_DONE event, remove the preloader
		// and add the application as the child
		preloader.removeEventListener(FlexEvent.PRELOADER_DONE,
									  preloader_preloaderDoneHandler);

		_popUpChildren.removeChild(preloader);
        preloader = null;

		// Add the mouseCatcher as child 0.
		mouseCatcher = new FlexSprite();
		mouseCatcher.name = "mouseCatcher";
		// Must use addChildAt because a creationComplete handler can create a
		// dialog and insert it at 0.
		noTopMostIndex++;
		super.addChildAt(mouseCatcher, 0);	
		resizeMouseCatcher();
		if (!topLevel)
		{
			mouseCatcher.visible = false;
			mask = mouseCatcher;
		}

		// Add the application as child 1.
		noTopMostIndex++;
		super.addChildAt(DisplayObject(app), 1);
		
		// Dispatch the applicationComplete event from the Application
		// and then agaom from the SystemManager
		// (so that loading apps know we're done).
		app.dispatchEvent(new FlexEvent(FlexEvent.APPLICATION_COMPLETE));
		dispatchEvent(new FlexEvent(FlexEvent.APPLICATION_COMPLETE));
	}

	/**
	 *  @private
	 *  This is attached as the framescript at the end of frame 2.
	 *  When this function is called, we know that the application
	 *  class has been defined and read in by the Player.
	 */
	mx_internal function docFrameHandler(event:Event = null):void
	{
		// The ResourceManager has already been registered 
		// by initialize() in frame 1.
		
		// Register other singleton classes.
		// Note: getDefinitionByName() will return null
		// if the class can't be found.

		Singleton.registerClass("mx.managers::IBrowserManager",
			Class(getDefinitionByName("mx.managers::BrowserManagerImpl")));

		Singleton.registerClass("mx.managers::ICursorManager",
			Class(getDefinitionByName("mx.managers::CursorManagerImpl")));

		Singleton.registerClass("mx.managers::IHistoryManager",
			Class(getDefinitionByName("mx.managers::HistoryManagerImpl")));

		Singleton.registerClass("mx.managers::ILayoutManager",
			Class(getDefinitionByName("mx.managers::LayoutManager")));

		Singleton.registerClass("mx.managers::IPopUpManager",
			Class(getDefinitionByName("mx.managers::PopUpManagerImpl")));

		Singleton.registerClass("mx.managers::IToolTipManager2",
			Class(getDefinitionByName("mx.managers::ToolTipManagerImpl")));

		if (Capabilities.playerType == "Desktop")
		{
			Singleton.registerClass("mx.managers::IDragManager",
				Class(getDefinitionByName("mx.managers::NativeDragManagerImpl")));
				
			// Make this call to create a new instance of the DragManager singleton. 
			// This will allow the application to receive NativeDragEvents that originate
			// from the desktop.
			// if this class is not registered, it's most likely because the NativeDragManager is not
			// linked in correctly. all back to old DragManager.
			if (Singleton.getClass("mx.managers::IDragManager") == null)
				Singleton.registerClass("mx.managers::IDragManager",
					Class(getDefinitionByName("mx.managers::DragManagerImpl")));
		}
		else
		{ 
			Singleton.registerClass("mx.managers::IDragManager",
				Class(getDefinitionByName("mx.managers::DragManagerImpl")));
		}

		var textFieldFactory:TextFieldFactory; // ref to cause TextFieldFactory to be linked in
		Singleton.registerClass("mx.core::ITextFieldFactory", 
			Class(getDefinitionByName("mx.core::TextFieldFactory")));


		executeCallbacks();
		doneExecutingInitCallbacks = true;

        var mixinList:Array = info()["mixins"];
		if (mixinList && mixinList.length > 0)
		{
		    var n:int = mixinList.length;
			for (var i:int = 0; i < n; ++i)
		    {
		        // trace("initializing mixin " + mixinList[i]);
		        var c:Class = Class(getDefinitionByName(mixinList[i]));
		        c["init"](this);
		    }
        }
		
		installCompiledResourceBundles();

		initializeTopLevelWindow(null);

		deferredNextFrame();
	}

	private function installCompiledResourceBundles():void
	{
		var info:Object = this.info();
		
		var applicationDomain:ApplicationDomain =
			!topLevel && parent is Loader ?
			Loader(parent).contentLoaderInfo.applicationDomain :
            info["currentDomain"];

		var compiledLocales:Array /* of String */ =
			info["compiledLocales"];

		var compiledResourceBundleNames:Array /* of String */ =
			info["compiledResourceBundleNames"];
		
		var resourceManager:IResourceManager =
			ResourceManager.getInstance();
		
		resourceManager.installCompiledResourceBundles(
			applicationDomain, compiledLocales, compiledResourceBundleNames);

		// If the localeChain wasn't specified in the FlashVars of the SWF's
		// HTML wrapper, or in the query parameters of the SWF URL,
		// then initialize it to the list of compiled locales,
        // sorted according to the system's preferred locales as reported by
        // Capabilities.languages or Capabilities.language.
		// For example, if the applications was compiled with, say,
		// -locale=en_US,ja_JP and Capabilities.languages reports [ "ja-JP" ],
        // set the localeChain to [ "ja_JP" "en_US" ].
		if (!resourceManager.localeChain)
			resourceManager.initializeLocaleChain(compiledLocales);
	}

	private function extraFrameHandler(event:Event = null):void
	{
	    var frameList:Object = info()["frames"];

	    if (frameList && frameList[currentLabel])
	    {
	        var c:Class = Class(getDefinitionByName(frameList[currentLabel]));
	        c["frame"](this);
	    }

	    deferredNextFrame();
	}

    /**
	 *  @private
	 */
	private function nextFrameTimerHandler(event:TimerEvent):void
	{
	    if (currentFrame + 1 <= framesLoaded)
	    {
	        nextFrame();
            nextFrameTimer.removeEventListener(TimerEvent.TIMER, nextFrameTimerHandler);
        	// stop the timer
        	nextFrameTimer.reset();
        }
    }
	
	/**
	 *  @private
	 *  Instantiates an instance of the top level window
	 *  and adds it as a child of the SystemManager.
	 */
	private function initializeTopLevelWindow(event:Event):void
	{
		initialized = true;

		// Parent may be null if in another sandbox and don't have
		// access to our parent.  Add a check for this case.
		if (!parent && canAccessParent())
			return;
		
		if (!topLevel)
		{
			var obj:DisplayObjectContainer = parent.parent;

  			// if there is no grandparent at this point, we might have been removed and
  			// are about to be killed so just bail.  Other code that runs after
  			// this point expects us to be grandparented.  Another scenario
  			// is that someone loaded us but not into a parented loader, but that
  			// is not allowed.
  			if (!obj)
  				return;
  
			while (obj)
			{
				if (obj is IUIComponent)
				{
					var sm:ISystemManager = IUIComponent(obj).systemManager;
					if (sm && !sm.isTopLevel())
						sm = sm.topLevelSystemManager;
						
					_topLevelSystemManager = sm;
					break;
				}
				obj = obj.parent;
			}
		}

		// capture mouse down so we can switch top level windows and activate
		// the right focus manager before the components inside start
		// processing the event
		if (isTopLevelRoot() || getSandboxRoot() == this)
		addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler, true); 

		if (isTopLevelRoot() && stage)
		 	stage.addEventListener(Event.RESIZE, Stage_resizeHandler, false, 0, true);
		else if (topLevel && stage)
		{
			// listen to resizes on the sandbox root
			var sandboxRoot:DisplayObject = getSandboxRoot();
			if (sandboxRoot != this)
				sandboxRoot.addEventListener(Event.RESIZE, Stage_resizeHandler, false, 0, true);
		}

		var app:IUIComponent;
		// Create a new instance of the toplevel class
        document = app = topLevelWindow = IUIComponent(create());

		if (document)
		{
			// Add listener for the creationComplete event
			IEventDispatcher(app).addEventListener(FlexEvent.CREATION_COMPLETE,
												   appCreationCompleteHandler);

			// if somebody has set this in our applicationdomain hierarchy, don't overwrite it
			if (!LoaderConfig._url)
			{
				LoaderConfig._url = loaderInfo.url;
				LoaderConfig._parameters = loaderInfo.parameters;
			}
				
			if (isStageRoot && stage)
			{
				// stageWidth/stageHeight may have changed between initialize() and now,
				// so refresh our _width and _height here. 
				_width = stage.stageWidth;
				_height = stage.stageHeight;
				
				IFlexDisplayObject(app).setActualSize(_width, _height);
			}
			else
				IFlexDisplayObject(app).setActualSize(loaderInfo.width, loaderInfo.height);

			// Wait for the app to finish its initialization sequence
			// before doing an addChild(). 
			// Otherwise, the measurement/layout code will cause the
			// player to do a bunch of unnecessary screen repaints,
			// which slows application startup time.
			
			// Pass the application instance to the preloader.
			// Note: preloader can be null when the user chooses
			// Control > Play in the standalone player.
			if (preloader)
				preloader.registerApplication(app);
						
			// The Application doesn't get added to the SystemManager in the standard way.
			// We want to recursively create the entire application subtree and process
			// it with the LayoutManager before putting the Application on the display list.
			// So here we what would normally happen inside an override of addChild().
			// Leter, when we actually attach the Application instance,
			// we call super.addChild(), which is the bare player method.
			addingChild(DisplayObject(app));
			childAdded(DisplayObject(app)); // calls app.createChildren()
		}
		else
		{
			document = this;
		}
	}
	
	
	/**
	 *  Override this function if you want to perform any logic
	 *  when the application has finished initializing itself.
	 */
	private function appCreationCompleteHandler(event:FlexEvent):void
	{
		if (!topLevel && parent)
		{
			var obj:DisplayObjectContainer = parent.parent;
			while (obj)
			{
				if (obj is IInvalidating)
				{
					IInvalidating(obj).invalidateSize();
					IInvalidating(obj).invalidateDisplayList();
					return;
				}
				obj = obj.parent;
			}
		}
 
		if (topLevel && useBridge())
		   dispatchInvalidateRequest();
	}

	/**
	 *  @private
	 *  Keep track of the size and position of the stage.
	 */
	private function Stage_resizeHandler(event:Event = null):void
	{	
		if (isDispatchingResizeEvent)
			return;

		var w:Number;
		var h:Number;
		var m:Number = loaderInfo.width;
		var n:Number = loaderInfo.height;

        // if we don't have access to the stage, when use the size of 
        // the sandbox root.                        
        try 
        {
            w = stage.stageWidth;
            h = stage.stageHeight;
        }
        catch (error:SecurityError)
        {
        	var sandboxScreen:Rectangle = getSandboxScreen();
        	w = sandboxScreen.width;
        	h = sandboxScreen.height;
        }
        
		var x:Number = (m - w) / 2;
		var y:Number = (n - h) / 2;
		
		// TODODJL: if not stage root defaulting to top,left.
		var align:String = isStageRoot ? stage.align : StageAlign.TOP_LEFT;

		if (align == StageAlign.TOP)
		{
			y = 0;
		}
		else if (align == StageAlign.BOTTOM)
		{
			y = n - h;
		}
		else if (align == StageAlign.LEFT)
		{
			x = 0;
		}
		else if (align == StageAlign.RIGHT)
		{
			x = m - w;
		}
		else if (align == StageAlign.TOP_LEFT || align == "LT") // player bug 125020
		{
			y = 0;
			x = 0;
		}
		else if (align == StageAlign.TOP_RIGHT)
		{
			y = 0;
			x = m - w;
		}
		else if (align == StageAlign.BOTTOM_LEFT)
		{
			y = n - h;
			x = 0;
		}
		else if (align == StageAlign.BOTTOM_RIGHT)
		{
			y = n - h;
			x = m - w;
		}
		
		if (!_screen)
			_screen = new Rectangle();
		_screen.x = x;
		_screen.y = y;
		_screen.width = w;
		_screen.height = h;

		if (isStageRoot)
		{
			_width = stage.stageWidth;
			_height = stage.stageHeight;
		}

		if (event)
		{
			resizeMouseCatcher();
			isDispatchingResizeEvent = true;
			dispatchEvent(event);
			isDispatchingResizeEvent = false;
		}
	}

	/**
	 *  @private
	 *  Track mouse clicks to see if we change top-level forms.
	 */
	private function mouseDownHandler(event:MouseEvent):void
	{
		// trace("SM:mouseDownHandler " + this);
		
		// Reset the idle counter.
		idleCounter = 0;

		// If an object was clicked that is inside another system manager 
		// in a bridged application, activate the current document because
		// the bridge application is considered part of the main application.
		// We also see mouse clicks on dialogs popped up from compatible applications.
		if (isDisplayObjectInABridgedApplication(event.target as DisplayObject))
		{
			// trace("SM:mouseDownHandler click in a bridged application");
			if (isTopLevelRoot())
				activateForm(document);
			else
				fireActivatedApplicationEvent();

			return;
		} 
		
		if (numModalWindows == 0) // no modal windows are up
		{
			if (!isTopLevelRoot() || forms.length > 1)
			{
				var n:int = forms.length;
				var p:DisplayObject = DisplayObject(event.target);
				var isApplication:Boolean = document is IRawChildrenContainer ? 
											IRawChildrenContainer(document).rawChildren.contains(p) :
											document.contains(p);
				while (p)
				{
					for (var i:int = 0; i < n; i++)
					{
						var form_i:Object = isRemotePopUp(forms[i]) ? forms[i].window : forms[i];
						if (form_i == p)
						{
							var j:int = 0;
							var index:int;
							var newIndex:int;
							var childList:IChildList;

							if (((p != form) && p is IFocusManagerContainer) ||
							    (!isTopLevelRoot() && p == form))
							{
								if (isTopLevelRoot())
								activate(IFocusManagerContainer(p));

								if (p == document)
									fireActivatedApplicationEvent();
								else if (p is DisplayObject)
									fireActivatedWindowEvent(DisplayObject(p));
							}
							
							if (popUpChildren.contains(p))
								childList = popUpChildren;
							else
								childList = this;

							index = childList.getChildIndex(p); 
							newIndex = index;
							
							//we need to reset n because activating p's 
							//FocusManager could have caused 
							//forms.length to have changed. 
							n = forms.length;
							for (j = 0; j < n; j++)
							{
								var f:DisplayObject;
								var isRemotePopUp:Boolean = isRemotePopUp(forms[j]);
								if (isRemotePopUp)
								{
									if (forms[j].window is String)
										continue;
									f = forms[j].window;
								}
								else 
									f = forms[j];
								if (isRemotePopUp)
								{
									var fChildIndex:int = getChildListIndex(childList, f);
									if (fChildIndex > index)
										newIndex = Math.max(fChildIndex, newIndex);	
								}
								else if (childList.contains(f))
									if (childList.getChildIndex(f) > index)
										newIndex = Math.max(childList.getChildIndex(f), newIndex);
							}
							if (newIndex > index && !isApplication)
								childList.setChildIndex(p, newIndex);

							return;
						}
					}
					p = p.parent;
				}
			}
			else 
				fireActivatedApplicationEvent();
		}
	}

	/**
	 * @private
	 * 
	 * Get the index of an object in a given child list.
	 * 
	 * @return index of f in childList, -1 if f is not in childList.
	 */ 
	private static function getChildListIndex(childList:IChildList, f:Object):int
	{
		var index:int = -1;
		try
		{
			index = childList.getChildIndex(DisplayObject(f)); 
		}
		catch (e:ArgumentError)
		{
			// index has been preset to -1 so just continue.	
		}
		
		return index; 
	}

	/**
	 *  @private
	 *  Track mouse moves in order to determine idle
	 */
	private function mouseMoveHandler(event:MouseEvent):void
	{
		// Reset the idle counter.
		idleCounter = 0;
	}

	/**
	 *  @private
	 *  Track mouse moves in order to determine idle.
	 */
	private function mouseUpHandler(event:MouseEvent):void
	{
		// Reset the idle counter.
		idleCounter = 0;
	}

	/**
	 *  @private
	 *  Called every IDLE_INTERVAL after the first listener
	 *  registers for 'idle' events.
	 *  After IDLE_THRESHOLD goes by without any user activity,
	 *  we dispatch an 'idle' event.
	 */
	private function idleTimer_timerHandler(event:TimerEvent):void
	{
		idleCounter++;

		if (idleCounter * IDLE_INTERVAL > IDLE_THRESHOLD)
			dispatchEvent(new FlexEvent(FlexEvent.IDLE));
	}

	//--------------------------------------------------------------------------
	//
	//  Sandbox Event handlers for messages from children
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 * 
	 * Sets the size of the stage on behalf of another system manager.
	 */
	private function setStageSizeRequestHandler(event:Event):void
	{
		var eObj:Object = Object(event);
		
		try
		{
			stage.width = eObj.width;
			stage.height = eObj.height;
		}
		catch (e:SecurityError)
		{
			if (sandboxBridgeGroup)
				sandboxBridgeGroup.parentBridge.dispatchEvent(event);
		}
	}

	/**
	 * @private
	 * 
	 * Add a popup request handler for domain local request and 
	 * remote domain requests.
	 */
	private function addPopupRequestHandler(event:Event):void
	{
		if (event.target != this && event is PopUpRequest)
			return;

		var popUpRequest:PopUpRequest = PopUpRequest.marshal(event);

		// If the is not for mutual trust between us an the child that wants the 
		// popup, then don't host the pop up.
		if (!SandboxUtil.hasMutualTrustWithChild(this, popUpRequest.bridge))
		{
			return;
		}
					
		var topMost:Boolean;

		// Need to have mutual trust between two application in order
		// for an application to host another application's popup.
		if (SandboxUtil.hasMutualTrustWithParent(this))
		{
			// ask the parent to host the popup
			popUpRequest.bridge = sandboxBridgeGroup.parentBridge;
			sandboxBridgeGroup.parentBridge.dispatchEvent(popUpRequest);
			return;
		}
		
		// add popup as a child of this system manager
        if (!popUpRequest.childList || popUpRequest.childList == PopUpManagerChildList.PARENT)
            topMost = popUpRequest.parent && popUpChildren.contains(popUpRequest.parent);
        else
            topMost = (popUpRequest.childList == PopUpManagerChildList.POPUP);

        var children:IChildList;
        children = topMost ? popUpChildren : this;
        children.addChild(DisplayObject(popUpRequest.window));
        
        if (popUpRequest.modal)    
	        numModalWindows++;
        
		// add popup to the list of managed forms
		var remoteForm:RemotePopUp = new RemotePopUp(popUpRequest.window, popUpRequest.bridge);
		forms.push(remoteForm);
		
		if (!isTopLevelRoot() && sandboxBridgeGroup)
		{
			// We've added the popup as far as it can go.
			// Add a placeholder to the top level root application
			var request:PopUpRequest = new PopUpRequest(PopUpRequest.ADD_PLACEHOLDER, 
			                                            popUpRequest.window, 
			                                            popUpRequest.bridge);
			request.placeholderId = NameUtil.displayObjectToString(DisplayObject(popUpRequest.window));
			dispatchEvent(request);
		}
	}
	
	/**
	 * @private
	 * 
	 * Message from a child system manager to 
	 * remove the popup that was added by using the
	 * addPopupRequestHandler.
	 */
	private function removePopupRequestHandler(event:Event):void
	{
		var popUpRequest:PopUpRequest = PopUpRequest.marshal(event);

		if (SandboxUtil.hasMutualTrustWithParent(this))
		{
			// since there is mutual trust the popup is hosted by the parent.
			sandboxBridgeGroup.parentBridge.dispatchEvent(popUpRequest);
			return;
		}
					
        if (popUpChildren.contains(popUpRequest.window))
            popUpChildren.removeChild(popUpRequest.window);
        else
            removeChild(DisplayObject(popUpRequest.window));
        
        if (popUpRequest.modal)    
			numModalWindows--;

		removeRemotePopUp(new RemotePopUp(popUpRequest.window, popUpRequest.bridge));
		
		if (!isTopLevelRoot() && sandboxBridgeGroup)
		{
			// if we got here we know the parent is untrusted, so remove placeholders
			var request:PopUpRequest = new PopUpRequest(PopUpRequest.REMOVE_PLACEHOLDER, 
														null,
														sandboxBridgeGroup.parentBridge);
			request.placeholderId = NameUtil.displayObjectToString(popUpRequest.window);
			dispatchEvent(request);
		}
		            
	}
	
	/**
	 * @private
	 * 
	 * Handle request to add a popup placeholder.
	 * The placeholder represents an untrusted form that is hosted 
	 * elsewhere.
	 */
	 private function addPlaceholderPopupRequestHandler(event:Event):void
	 {
		var popUpRequest:PopUpRequest = PopUpRequest.marshal(event);

		if (event.target != this && event is PopUpRequest)
			return;
	 	
		if (!forwardPlaceholderRequest(popUpRequest, true))
		{
			// Create a RemotePopUp and add it.
			var remoteForm:RemotePopUp = new RemotePopUp(popUpRequest.placeholderId, popUpRequest.bridge);
			forms.push(remoteForm);
		}

	 }

	/**
	 * @private
	 * 
	 * Handle request to add a popup placeholder.
	 * The placeholder represents an untrusted form that is hosted 
	 * elsewhere.
	 */
	 private function removePlaceholderPopupRequestHandler(event:Event):void
	 {
		var popUpRequest:PopUpRequest = PopUpRequest.marshal(event);
	 	
		if (!forwardPlaceholderRequest(popUpRequest, false))
		{
	        // remove the placeholder from forms array
			var n:int = forms.length;
			for (var i:int = 0; i < n; i++)
			{
				if (isRemotePopUp(forms[i]))
				{
					if (forms[i].window == popUpRequest.placeholderId &&
					    forms[i].bridge == popUpRequest.bridge)
					{
						forms.splice(i, 1);
						break;
					}
				}
			}
		}			 	
		
	 }

	/**
	 * Forward a form event update the parent chain. 
	 * Takes care of removing object references and substituting
	 * ids when an untrusted boundry is crossed.
	 */
	private function forwardFormEvent(eObj:Object):Boolean
	{
		
		if (isTopLevelRoot())
			return false;			
			
		var bridge:IEventDispatcher = sandboxBridgeGroup.parentBridge; 
		if (bridge)
		{
			var sbRoot:DisplayObject = getSandboxRoot();
			eObj.sender =  bridge;
			if (sbRoot == this)
			{
				if (!(eObj.data is String))
					eObj.data = NameUtil.displayObjectToString(DisplayObject(eObj.data));
				else
					eObj.data = NameUtil.displayObjectToString(DisplayObject(this)) + "." + eObj.data;
				
				bridge.dispatchEvent(Event(eObj));
			}
			else
			{
				if (eObj.data is String)
					eObj.data = NameUtil.displayObjectToString(DisplayObject(this)) + "." + eObj.data;
 
				sbRoot.dispatchEvent(Event(eObj));
			}
		}

		return true;
	}
	
	/**
	 * Forward an AddPlaceholder request up the parent chain, if needed.
	 * 
	 * @param eObj PopupRequest as and Object.
	 * @param addPlaceholder true if adding a placeholder, false it removing a placeholder.
	 * @return true if the request was forwared, false otherwise
	 */
	private function forwardPlaceholderRequest(eObj:Object, addPlaceholder:Boolean):Boolean
	{
	 	// Only the top level root tracks the placeholders.
	 	// If we are not the top level root then keep passing
	 	// the message up the parent chain.
	 	if (isTopLevelRoot())
	 		return false;
	 		
		// If the window object is passed, then this is the first
		// stop on the way up the parent chain.
		var refObj:Object = null;
		var oldId:String = null;
		if (eObj.window)
		{
			refObj = eObj.window;
			
			// null this ref out so untrusted parent cannot see
			eObj.window = null;
		}
		else
		{
			refObj = eObj.bridge;
			
			// prefix the existing id with the id of this object
			oldId = eObj.placeholderId;
			eObj.placeholderId = NameUtil.displayObjectToString(this) + "." + eObj.placeholderId;
		}

		if (addPlaceholder)
			addPlaceholderId(eObj.placeholderId, oldId, eObj.bridge, refObj);
		else 
			removePlaceholderId(eObj.placeholderId);
				
		
		var sbRoot:DisplayObject = getSandboxRoot();
		var bridge:IEventDispatcher = sandboxBridgeGroup.parentBridge; 
		eObj.bridge =  bridge;
		if (sbRoot == this)
			bridge.dispatchEvent(Event(eObj));
		else 
			sbRoot.dispatchEvent(Event(eObj));
			
		return true;
	}

	/**
	 * One of the system managers in another sandbox deactivated and sent a message
	 * to the top level system manager. In response the top-level system manager
	 * needs to find a new form to activate.
	 */
	private function deactivateFormSandboxEventHandler(event:Event):void
	{
		// trace("bridgeDeactivateFormEventHandler");

		if (event is SandboxBridgeRequest)
			return;

		var eObj:Object = Object(event);

		if (!forwardFormEvent(eObj))
		{
			// deactivate the form
			if (isRemotePopUp(form) && 
				RemotePopUp(form).window == eObj.data &&
				RemotePopUp(form).bridge == eObj.sender)
				deactivateForm(form);
		}
	}
	
	
	/**
	 * A form in one of the system managers in another sandbox has been activated. 
	 * The form being activate is identified. 
	 * In response the top-level system manager needs to activate the given form
	 * and deactivate the currently active form, if any.
	 */
	private function activateFormSandboxEventHandler(event:Event):void
	{
		// trace("bridgeActivateFormEventHandler");
		var eObj:Object = event;

		if (!forwardFormEvent(eObj))
			// just call activate on the remote form.
			activateForm(new RemotePopUp(eObj.data, eObj.sender));			
	}
		
	/**
	 * One of the system managers in another sandbox activated and sent a message
	 * to the top level system manager to deactivate this form. In response the top-level system manager
	 * needs to deactivate all other forms except the top level system manager's.
	 */
	private function activateApplicationSandboxEventHandler(event:Event):void
	{
		// trace("bridgeActivateApplicationEventHandler");
		if (!isTopLevelRoot())
		{
			sandboxBridgeGroup.parentBridge.dispatchEvent(event);
			return;    	
		}

		// An application was activated, active the main document.
		activateForm(document);
	}


    /**
     *  @private
     * 
     *  Re-dispatch events sent over the bridge to listeners on this
     *  system manager. PopUpManager is expected to listen to these
     *  events.
     */  
    private function modalWindowRequestHandler(event:Event):void
    {
        if (event is ModalWindowRequest)
            return;
        
        var request:ModalWindowRequest = ModalWindowRequest.marshal(event);
            
        // Ensure a PopUpManager exists and dispatch the request it is
        // listening for.
        Singleton.getInstance("mx.managers::IPopUpManager");
        dispatchEvent(request);
    }

	//--------------------------------------------------------------------------
	//
	//  Sandbox Event handlers for messages from parent
	//
	//--------------------------------------------------------------------------
	
	/**
	 * @private
	 * 
	 * Sent by the SWFLoader to change the size of the application it loaded.
	 */
	private function setActualSizeRequestHandler(event:Event):void
	{
		var eObj:Object = Object(event);
		setActualSize(eObj.width, eObj.height);
	}
	
	/**
	 * @private
	 * 
	 * Get the size of this System Manager.
	 * Sent by a SWFLoader.
	 */
	private function getSizeRequestHandler(event:Event):void
	{
		var eObj:Object = Object(event);
		eObj.width = measuredWidth;
		eObj.height = measuredHeight;					
	}
	
	/**
	 * @private
	 * 
	 * Handle request to activate a particular form.
	 * 
	 */
	private function activateRequestHandler(event:Event):void
	{
		var eObj:Object = Object(event);

		// If data is a String, then we need to parse the id to find
		// the form or the next bridge to pass the message to.
		// If the data is a SystemMangerProxy we can just activate the
		// form.
		var child:Object = eObj.data; 
		var nextId:String = null;
		if (eObj.data is String)
		{
			var placeholder:PlaceholderData = idToPlaceholder[eObj.data];
			child = placeholder.data;
			nextId = placeholder.id;
			
			// check if the dialog is hosted on this system manager
			if (nextId == null)
			{
				var popUp:RemotePopUp = findRemotePopUp(child, placeholder.bridge); 
				
				if (popUp)
				{
					activateRemotePopUp(popUp);
					return;
				}
			}
		}
		
		if (child is SystemManagerProxy)
		{
			// deactivate request from the top-level system manager.
			var smp:SystemManagerProxy = SystemManagerProxy(eObj.data);
			var f:IFocusManagerContainer = findFocusManagerContainer(smp);
			if (smp && f)
				smp.activateProxy(f);
		}	
		else if (child is IFocusManagerContainer)
			IFocusManagerContainer(child).focusManager.activate();
		else if (child is IEventDispatcher)
		{
				eObj.data = nextId;
				eObj.requestor = child;
				IEventDispatcher(child).dispatchEvent(event);
		}
		else 
			throw new Error();	// should never get here
	}

	/**
	 * @private
	 * 
	 * Handle request to deactivate a particular form.
	 * 
	 */
	private function deactivateRequestHandler(event:Event):void
	{
		var eObj:Object = Object(event);

		var child:Object = eObj.data; 
		var nextId:String = null;
		if (eObj.data is String)
		{
			var placeholder:PlaceholderData = idToPlaceholder[eObj.data];
			child = placeholder.data;
			nextId = placeholder.id;

			// check if the dialog is hosted on this system manager
			if (nextId == null)
			{
				var popUp:RemotePopUp = findRemotePopUp(child, placeholder.bridge); 
				
				if (popUp)
				{
					deactivateRemotePopUp(popUp);
					return;
				}
			}
		}
		
		if (child is SystemManagerProxy)
		{
			// deactivate request from the top-level system manager.
			var smp:SystemManagerProxy = SystemManagerProxy(child);
			var f:IFocusManagerContainer = findFocusManagerContainer(smp);
			if (smp && f)
				smp.deactivateProxy(f);
		}
		else if (child is IFocusManagerContainer)
			IFocusManagerContainer(child).focusManager.deactivate();
			
		else if (child is IEventDispatcher)
		{
			eObj.data = nextId;
			eObj.requestor = child;
			IEventDispatcher(child).dispatchEvent(event);
			return;
		}
		else
			throw new Error();		
	}

	//--------------------------------------------------------------------------
	//
	//  Sandbox Event handlers for messages from either the
	//  parent or child
	//
	//--------------------------------------------------------------------------

	/**
	 * Is the child in event.data this system manager or a child of this 
	 * system manager?
	 *
	 * If the display object is a child event.preventDefault is called,
	 * otherwise nothing is done. 
	 */
	private function isBridgeChildHandler(event:Event):void
	{
		// if we are broadcasting messages, ignore the messages
		// we send to ourselves.
		if (event is SandboxBridgeRequest)
			return;

		var eObj:Object = Object(event);

		if (eObj.data && rawChildren.contains(eObj.data as DisplayObject))
		{
			event.preventDefault();
		}
	}
	
	/**
	 * Can this form be activated. The current test is if the given pop up 
	 * is visible and is enabled. 
	 *
	 * If the can be activated event.preventDefault is called,
	 * otherwise nothing is done. 
	 */
	private function canActivateHandler(event:Event):void
	{
		var eObj:Object = Object(event);

		// If data is a String, then we need to parse the id to find
		// the form or the next bridge to pass the message to.
		// If the data is a SystemMangerProxy we can just activate the
		// form.
		var request:SandboxBridgeRequest;
		var child:Object = eObj.data; 
		var nextId:String = null;
		if (eObj.data is String)
		{
			var placeholder:PlaceholderData = idToPlaceholder[eObj.data];
			child = placeholder.data;
			nextId = placeholder.id;
			
			// check if the dialog is hosted on this system manager
			if (nextId == null)
			{
				var popUp:RemotePopUp = findRemotePopUp(child, placeholder.bridge); 
				
				if (popUp)
				{
					request = new SandboxBridgeRequest(SandboxBridgeRequest.CAN_ACTIVATE,
																false, true, 
																IEventDispatcher(popUp.bridge), 
																popUp.window);
				 	if (popUp.bridge)
				 	{
				 		popUp.bridge.dispatchEvent(request);
				 		if (request.isDefaultPrevented())
				 			event.preventDefault();
				 	}
					return;
				}
			}
		}
		
		if (child is SystemManagerProxy)
		{
			var smp:SystemManagerProxy = SystemManagerProxy(child);
			var f:IFocusManagerContainer = findFocusManagerContainer(smp);
			if (smp && f && canActivateLocalComponent(f))
				event.preventDefault();
		}	
		else if (child is IFocusManagerContainer)
		{
			if (canActivateLocalComponent(child))
				event.preventDefault();
		}
		else if (child is IEventDispatcher)
		{
			var bridge:IEventDispatcher = IEventDispatcher(child);
		    request = new SandboxBridgeRequest(SandboxBridgeRequest.CAN_ACTIVATE,
															false, true, 
															bridge, 
															nextId);
			
			if (bridge)
			{
				bridge.dispatchEvent(request);
				if (request.isDefaultPrevented())
					event.preventDefault();
			}
		}
		else 
			throw new Error();	// should never get here
	}
	

	/**
	 * @private
	 * 
	 * Test if a display object is in an applcation we want to communicate with over a bridge.
	 * 
	 */
	public function isDisplayObjectInABridgedApplication(displayObject:DisplayObject):Boolean
	{
		if (sandboxBridgeGroup)
		{
			var request:SandboxBridgeRequest = new SandboxBridgeRequest(SandboxBridgeRequest.IS_BRIDGE_CHILD,
																		false, true, null, displayObject);
			var children:Array = sandboxBridgeGroup.getChildBridges();
			var n:int = children.length;
			for (var i:int = 0; i < n; i++)
			{
				var childBridge:IEventDispatcher = IEventDispatcher(children[i]);
				
				// No need to test a child if it does not trust us, we will never see
				// their display objects.
				// Also, if the we don't trust the child don't send them a display object.
				if (sandboxBridgeGroup.canAccessChildBridge(childBridge) &&
					sandboxBridgeGroup.accessibleFromChildBridge(childBridge) &&
					!childBridge.dispatchEvent(request))
					return true;
			}
		}
			
		return false;
	}

	/**
	 * Create the requested manager
	 */
	private function initManagerHandler(event:Event):void
	{
		// if we are broadcasting messages, ignore the messages
		// we send to ourselves.
		if (event is MarshalEvent)
			return;

		// initialize the registered manager implementation
		var name:String = event["name"];
		Singleton.getInstance(name);
	}

	/**
	 * Create the requested manager
	 */
	public function addChildToSandboxRoot(layer:String, child:DisplayObject):void
	{
		if (getSandboxRoot() == this)
		{
			this[layer].addChild(child);
		}
		else
		{
			addingChild(child);
			var me:MarshalEvent = new MarshalEvent(MarshalEvent.SYSTEM_MANAGER);
			me.name = layer + ".addChild";
			me.value = child;
			getSandboxRoot().dispatchEvent(me);
			childAdded(child);
		}
	}

	/**
	 * Create the requested manager
	 */
	public function removeChildFromSandboxRoot(layer:String, child:DisplayObject):void
	{
		if (getSandboxRoot() == this)
		{
			this[layer].removeChild(child);
		}
		else
		{
			removingChild(child);
			var me:MarshalEvent = new MarshalEvent(MarshalEvent.SYSTEM_MANAGER);
			me.name = layer + ".removeChild";
			me.value = child;
			getSandboxRoot().dispatchEvent(me);
			childRemoved(child);
		}
	}


	/**
	 * marshal some data
	 */
	private function marshalHandler(event:Event):void
	{
		// if we are broadcasting messages, ignore the messages
		// we send to ourselves.
		if (event is MarshalEvent)
			return;

		var eventObj:Object = event;
		var value:Object = eventObj.value.value;
		var type:Class = eventObj.value.type;

		var info:Object = ObjectUtil.getClassInfo(value);

		var alias:String = info.alias;

		var currentType:Class = getClassByAlias(alias);
		var ba:ByteArray = new ByteArray();
		ba.writeObject(value);
		registerClassAlias(alias, type);
		ba.position = 0;
		value = ba.readObject();
		eventObj.value = value;
		registerClassAlias(alias, currentType);

	}

	/**
	 * perform the requested action from a trusted dispatcher
	 */
	private function systemManagerHandler(event:Event):void
	{
		if (event["name"] == "sameSandbox")
		{
			event["value"] = currentSandboxEvent == event["value"];
			return;
		}

		// if we are broadcasting messages, ignore the messages
		// we send to ourselves.
		if (event is MarshalEvent)
			return;

		// initialize the registered manager implementation
		var name:String = event["name"];

		switch (name)
		{
		case "popUpChildren.addChild":
			popUpChildren.addChild(event["value"]);
			break;
		case "popUpChildren.removeChild":
			popUpChildren.removeChild(event["value"]);
			break;
		case "cursorChildren.addChild":
			cursorChildren.addChild(event["value"]);
			break;
		case "cursorChildren.removeChild":
			cursorChildren.removeChild(event["value"]);
			break;
		case "toolTipChildren.addChild":
			toolTipChildren.addChild(event["value"]);
			break;
		case "toolTipChildren.removeChild":
			toolTipChildren.removeChild(event["value"]);
			break;
		case "screen":
			event["value"] = screen;
			break;
		case "application":
		    event["value"] = application;
		}
	}
	
	// fake out mouseX/mouseY
	mx_internal var _mouseX:*;
	mx_internal var _mouseY:*;


	/**
	 *  @private
	 */
	override public function get mouseX():Number
	{
		if (_mouseX === undefined)
			return super.mouseX;
		return _mouseX;
	}

	/**
	 *  @private
	 */
	override public function get mouseY():Number
	{
		if (_mouseY === undefined)
			return super.mouseY;
		return _mouseY;
	}
	
	/**
	 * Return the object the player sees as having focus.
	 * 
	 * @return An object of type InteractiveObject that the
	 * 		   player sees as having focus. If focus is currently
	 * 		   in a sandbox the caller does not have access to
	 * 		   null will be returned.
	 */
	public function getFocus():InteractiveObject
	{
		try
		{
			return stage.focus;
		}	
		catch (e:SecurityError)
		{
			// trace("SM getFocus(): ignoring security error " + e);
		}

		return null;
	}	
	
	
	/**
	 * Get the size of our sandbox's screen property.
	 * 
	 * Only the screen property should need to call this function.
	 * 
	 * The function assumes the caller does not have access to the stage.
	 * 
	 */
	private function getSandboxScreen():Rectangle
	{
    	// If we don't have access to the stage, use the size of
    	// our sandbox root.
    	var sandboxRoot:DisplayObject = getSandboxRoot();
    	var sandboxScreen:Rectangle;
    	
    	if (sandboxRoot == this)
    		// we don't have access the stage so use the width and
    		// height of the application.
   			sandboxScreen = new Rectangle(0, 0, width, height);			
    	else if (sandboxRoot == topLevelSystemManager)
    	{
    		var sm:DisplayObject = DisplayObject(topLevelSystemManager);
    		sandboxScreen = new Rectangle(0, 0, sm.width, sm.height);
    	}
    	else
    	{
	    	var me:MarshalEvent = new MarshalEvent(MarshalEvent.SYSTEM_MANAGER, false, false,
    											   "screen");
    		sandboxRoot.dispatchEvent(me);		
    	
    		// me.value now contains the screen property of the sandbox root.
    		sandboxScreen = Rectangle(me.value);
    	}

		return sandboxScreen;
	}	

	/**
	 * The system manager proxy has only one child that is a focus manager container.
	 * Iterate thru the children until we find it.
	 */
	private function findFocusManagerContainer(smp:SystemManagerProxy):IFocusManagerContainer
	{
		var children:IChildList = smp.rawChildren;
		var numChildren:int = children.numChildren;
		for (var i:int = 0; i < numChildren; i++)
		{
			var child:DisplayObject = children.getChildAt(i);
			if (child is IFocusManagerContainer)
			{
				return IFocusManagerContainer(child);
			}
		}
		
		return null;
	}

	/**
	 * @inheritdoc
	 * 
	 */
	public function invalidateStage():void
	{
		if (stage)
			stage.invalidate();
	}

	/**
	 * @private
	 * 
	 * Listen to messages this System Manager needs to service from its children.
	 */	
	mx_internal function addChildBridgeListeners(bridge:IEventDispatcher):void
	{
		if (!topLevel && topLevelSystemManager)
		{
			SystemManager(topLevelSystemManager).addChildBridgeListeners(bridge);
			return;
		}
		
		bridge.addEventListener(PopUpRequest.ADD, addPopupRequestHandler);
		bridge.addEventListener(PopUpRequest.REMOVE, removePopupRequestHandler);
		bridge.addEventListener(PopUpRequest.ADD_PLACEHOLDER, addPlaceholderPopupRequestHandler);
		bridge.addEventListener(PopUpRequest.REMOVE_PLACEHOLDER, removePlaceholderPopupRequestHandler);
		bridge.addEventListener(SandboxBridgeEvent.ACTIVATE_WINDOW, activateFormSandboxEventHandler);
		bridge.addEventListener(SandboxBridgeEvent.DEACTIVATE_WINDOW, deactivateFormSandboxEventHandler); 
		bridge.addEventListener(SandboxBridgeEvent.ACTIVATE_APPLICATION, activateApplicationSandboxEventHandler);
		bridge.addEventListener(EventListenerRequest.ADD, eventListenerRequestHandler, false, 0, true);
		bridge.addEventListener(EventListenerRequest.REMOVE, eventListenerRequestHandler, false, 0, true);
        bridge.addEventListener(ModalWindowRequest.CREATE, modalWindowRequestHandler);
        bridge.addEventListener(ModalWindowRequest.SHOW, modalWindowRequestHandler);
        bridge.addEventListener(ModalWindowRequest.HIDE, modalWindowRequestHandler);
	}

	/**
	 * @private
	 * 
	 * Remove all child listeners.
	 */
	mx_internal function removeChildBridgeListeners(bridge:IEventDispatcher):void
	{
		if (!topLevel && topLevelSystemManager)
		{
			SystemManager(topLevelSystemManager).removeChildBridgeListeners(bridge);
			return;
		}
		
		bridge.removeEventListener(PopUpRequest.ADD, addPopupRequestHandler);
		bridge.removeEventListener(PopUpRequest.REMOVE, removePopupRequestHandler);
		bridge.removeEventListener(PopUpRequest.ADD_PLACEHOLDER, addPlaceholderPopupRequestHandler);
		bridge.removeEventListener(PopUpRequest.REMOVE_PLACEHOLDER, removePlaceholderPopupRequestHandler);
		bridge.removeEventListener(SandboxBridgeEvent.ACTIVATE_WINDOW, activateFormSandboxEventHandler);
		bridge.removeEventListener(SandboxBridgeEvent.DEACTIVATE_WINDOW, deactivateFormSandboxEventHandler); 
		bridge.removeEventListener(SandboxBridgeEvent.ACTIVATE_APPLICATION, activateApplicationSandboxEventHandler);
		bridge.removeEventListener(EventListenerRequest.ADD, eventListenerRequestHandler);
		bridge.removeEventListener(EventListenerRequest.REMOVE, eventListenerRequestHandler);
        bridge.removeEventListener(ModalWindowRequest.CREATE, modalWindowRequestHandler);
        bridge.removeEventListener(ModalWindowRequest.SHOW, modalWindowRequestHandler);
        bridge.removeEventListener(ModalWindowRequest.HIDE, modalWindowRequestHandler);
	}

	/**
	 * @private
	 * 
	 * Add listeners for events and requests we might receive from our parent if our
	 * parent is using a sandbox bridge to communicate with us.
	 */
	mx_internal function addParentBridgeListeners():void
	{
		if (!topLevel && topLevelSystemManager)
		{
			SystemManager(topLevelSystemManager).addParentBridgeListeners();
			return;
		}
		
		var bridge:IEventDispatcher = sandboxBridgeGroup.parentBridge;
		bridge.addEventListener(SizeRequest.SET_ACTUAL_SIZE, setActualSizeRequestHandler);
		bridge.addEventListener(SizeRequest.GET_SIZE, getSizeRequestHandler);
//		bridge.addEventListener(SandboxBridgeEvent.TOP_LEVEL_APPLICATION, 
//								topLevelSystemManagerEventHandler);

		// need to listener to parent system manager to get broadcast messages.
		bridge.addEventListener(SandboxBridgeRequest.ACTIVATE, 
								activateRequestHandler); 
		bridge.addEventListener(SandboxBridgeRequest.DEACTIVATE, 
								deactivateRequestHandler); 
		bridge.addEventListener(SandboxBridgeRequest.IS_BRIDGE_CHILD, isBridgeChildHandler);
		bridge.addEventListener(EventListenerRequest.ADD, eventListenerRequestHandler, false, 0, true);
		bridge.addEventListener(EventListenerRequest.REMOVE, eventListenerRequestHandler, false, 0, true);
		bridge.addEventListener(SandboxBridgeRequest.CAN_ACTIVATE, canActivateHandler);
	}
	
	/**
	 * @private
	 * 
	 * remove listeners for events and requests we might receive from our parent if 
	 * our parent is using a sandbox bridge to communicate with us.
	 */
	mx_internal function removeParentBridgeListeners():void
	{
		if (!topLevel && topLevelSystemManager)
		{
			SystemManager(topLevelSystemManager).removeParentBridgeListeners();
			return;
		}
		
		var bridge:IEventDispatcher = sandboxBridgeGroup.parentBridge;
		bridge.removeEventListener(SizeRequest.SET_ACTUAL_SIZE, setActualSizeRequestHandler);
		bridge.removeEventListener(SizeRequest.GET_SIZE, getSizeRequestHandler);

		// need to listener to parent system manager to get broadcast messages.
		bridge.removeEventListener(SandboxBridgeRequest.ACTIVATE, 
								activateRequestHandler); 
		bridge.removeEventListener(SandboxBridgeRequest.DEACTIVATE, 
								deactivateRequestHandler); 
		bridge.removeEventListener(SandboxBridgeRequest.IS_BRIDGE_CHILD, isBridgeChildHandler);
		bridge.removeEventListener(EventListenerRequest.ADD, eventListenerRequestHandler);
		bridge.removeEventListener(EventListenerRequest.REMOVE, eventListenerRequestHandler);
		bridge.addEventListener(SandboxBridgeRequest.CAN_ACTIVATE, canActivateHandler);
	}
	
	private function getTopLevelSystemManager(parent:DisplayObject):ISystemManager
	{
	    var localRoot:DisplayObjectContainer = DisplayObjectContainer(parent.root);
		var sm:ISystemManager;
		
        // If the parent isn't rooted yet,
        // Or the root is the stage (which is the case in a second AIR window)
        // use the global system manager instance.
        if ((!localRoot || localRoot is Stage) && parent is IUIComponent)
            localRoot = DisplayObjectContainer(IUIComponent(parent).systemManager);
        if (localRoot is ISystemManager)
        {
            sm = ISystemManager(localRoot);
            if (!sm.isTopLevel())
                sm = sm.topLevelSystemManager;
        }

		return sm;
	}

	private function isNotContentIFlexDisplayObjectHandler(event:Event):void
	{
		event.preventDefault();		// returns false which means we are a IFlexDisplayObject
		return;	
	}
	
	/**
	 * Override parent property to handle the case where the parent is in
	 * a differnt sandbox. If the parent is in the same sandbox it is returned.
	 * If the parent is in a diffent sandbox, then null is returned.
	 * 
	 */	
	override public function get parent():DisplayObjectContainer
	{
		try
		{
			return super.parent;
		}	
		catch (e:SecurityError) 
		{
			// trace("parent: ignoring security error");
		}
		
		return null;
	}

	/**
	 * Add a bridge to talk to the child owned by <code>owner</code>.
	 * 
	 * @param owner the display object that owns the bridge.
	 * @param bridge the bridge used to talk to the parent. 
	 */	
	public function addChildSandboxBridge(owner:DisplayObject, bridge:IEventDispatcher):void
	{
		if (!sandboxBridgeGroup)
			sandboxBridgeGroup = new SandboxBridgeGroup(this);

   		sandboxBridgeGroup.addChildBridge(owner, bridge);
        addChildBridgeListeners(bridge);
		IFocusManagerContainer(document).focusManager.addFocusManagerBridge(bridge);
	}

	/**
	 * Remove a child bridge.
	 */
	public function removeChildSandboxBridge(bridge:IEventDispatcher):void
	{
		IFocusManagerContainer(document).focusManager.removeFocusManagerBridge(bridge);
   		sandboxBridgeGroup.removeChildBridge(bridge);
        removeChildBridgeListeners(bridge);
	}

	/**
	 * @inheritdoc
	 */
	public function useBridge():Boolean
	{
		if (isStageRoot)
			return false;
			
		if (!topLevel && topLevelSystemManager)
			return ISystemManager2(topLevelSystemManager).useBridge();
			
		// if we're toplevel and we aren't the sandbox root, we need a bridge
		if (topLevel && getSandboxRoot() != this)
			return true;
		
		// we also need a bridge even if we're the sandbox root
		// but not a stage root, but our parent loader is a bootstrap
		// that is not the stage root
		if (getSandboxRoot() == this)
		{
			try
			{
				if (root.loaderInfo.parentAllowsChild)
				{
					try
					{
						if (!parent.dispatchEvent(new Event("mx.managers.SystemManager.isStageRoot", false, true)))
							return true;
					}
					catch (e:Error)
					{
					}
				}
				else
					return true;
			}
			catch (e1:Error)
			{
				// we seem to get here when a SWF is being unloaded, has been unparented, but still
				// has a stage and root property, but loaderInfo is invalid.
				return false;
			}
		}

		return false;
	}
	
	/**
	 * Go up our parent chain to get the top level system manager.
	 * 
	 * returns null if we are not on the display list or we don't have
	 * access to the top level system manager.
	 */
	public function getTopLevelRoot():DisplayObject
	{
		// work our say up the parent chain to the root. This way we
		// don't have to rely on this object being added to the stage.
		try
		{
			var sm:ISystemManager2 = this;
			if (sm.topLevelSystemManager)
				sm = ISystemManager2(sm.topLevelSystemManager);
			var parent:DisplayObject = DisplayObject(sm).parent;
			var lastParent:DisplayObject = parent;
			while (parent)
			{
				if (parent is Stage)
					return lastParent;
				lastParent = parent; 
				parent = parent.parent;				
			}
		}
		catch (error:SecurityError)
		{
		}		
		
		return null;
	}

	/**
	 * Go up our parent chain to get the top level system manager in this 
	 * SecurityDomain
	 * 
	 */
	public function getSandboxRoot():DisplayObject
	{
		// work our say up the parent chain to the root. This way we
		// don't have to rely on this object being added to the stage.
		var sm:ISystemManager2 = this;

		try
		{
			if (sm.topLevelSystemManager)
				sm = ISystemManager2(sm.topLevelSystemManager);
			var parent:DisplayObject = DisplayObject(sm).parent;
			if (parent is Stage)
				return DisplayObject(sm);
			// test to see if parent is a Bootstrap
			if (parent && !parent.dispatchEvent(new Event("mx.managers.SystemManager.isBootstrapRoot", false, true)))
				return this;
			var lastParent:DisplayObject = parent;
			while (parent)
			{
				if (parent is Stage)
					return lastParent;
				// test to see if parent is a Bootstrap
				if (!parent.dispatchEvent(new Event("mx.managers.SystemManager.isBootstrapRoot", false, true)))
					return lastParent;
				lastParent = parent; 
				parent = parent.parent;				
			}
		}
		catch (error:SecurityError)
		{
			// don't have access to parent	
		}		
		
		return lastParent != null ? lastParent : DisplayObject(sm);
	}
	
	/**
	 * @private
	 * 
	 * Notify parent that a new window has been activated.
	 * 
	 * @param window window that was activated.
	 */
	mx_internal function fireActivatedWindowEvent(window:DisplayObject):void
	{
		var bridge:IEventDispatcher = sandboxBridgeGroup ? sandboxBridgeGroup.parentBridge : null;
		if (bridge)
		{
			var sbRoot:DisplayObject = getSandboxRoot();
			var sendToSbRoot:Boolean = sbRoot != this;
			var bridgeEvent:SandboxBridgeEvent = new SandboxBridgeEvent(SandboxBridgeEvent.ACTIVATE_WINDOW,
																	    false, false,
	       																bridge, 
	       																sendToSbRoot ? window :
	       																NameUtil.displayObjectToString(window));
	        if (sendToSbRoot)
	        	sbRoot.dispatchEvent(bridgeEvent);
			else
				bridge.dispatchEvent(bridgeEvent);
		}
		
	}

	/**
	 * @private
	 * 
	 * Notify parent that a window has been deactivated.
	 * 
	 * @param id window display object or id string that was activated. Ids are used if
	 * 		  the message is going outside the security domain.
	 */
	private function fireDeactivatedWindowEvent(window:DisplayObject):void
	{
		var bridge:IEventDispatcher = sandboxBridgeGroup ? sandboxBridgeGroup.parentBridge : null;
		if (bridge)
		{
			var sbRoot:DisplayObject = getSandboxRoot();
			var sendToSbRoot:Boolean = sbRoot != this;
			var bridgeEvent:SandboxBridgeEvent = new SandboxBridgeEvent(SandboxBridgeEvent.DEACTIVATE_WINDOW,
																	    false, 
																	    false,
	       																bridge, 
	       																sendToSbRoot ? window :
	       																NameUtil.displayObjectToString(window));
	        if (sendToSbRoot)
	        	sbRoot.dispatchEvent(bridgeEvent);
			else
				bridge.dispatchEvent(bridgeEvent);
		}
		
	}
	
	
	/**
	 * @private
	 * 
	 * Notify parent that an application has been activated.
	 */
	private function fireActivatedApplicationEvent():void
	{
		// click on this system manager or one of its sub system managers
		// If in a sandbox tell the top-level system manager we are active.
		var bridge:IEventDispatcher = sandboxBridgeGroup ? sandboxBridgeGroup.parentBridge : null;
		if (bridge)
		{
			var bridgeEvent:SandboxBridgeEvent = new SandboxBridgeEvent(SandboxBridgeEvent.ACTIVATE_APPLICATION,
																		false, false,
																		bridge);
			bridge.dispatchEvent(bridgeEvent);
		}
	}

	/**
	 * Adjust the forms array so it is sorted by last active. 
	 * The last active form will be at the end of the forms array.
	 * 
	 * This method assumes the form variable has been set before calling
	 * this function.
	 */
	private function updateLastActiveForm():void
	{
		// find "form" in the forms array and move that entry to 
		// the end of the array.
		var n:int = forms.length;
		if (n < 2)
			return;	// zero or one forms, no need to update
			
		var index:int = -1;
		for (var i:int = 0; i < n; i++)
		{
			if (areFormsEqual(form, forms[i]))
			{
				index = i;
				break;
			}
		}
		
		if (index >= 0)
		{
			forms.splice(index, 1);
			forms.push(form);
		}
		else
			throw new Error();	// should never get here
		
	}

	/**
	 * @private
	 * 
	 * Add placeholder information to this instance's list of placeholder data.
	 */ 	
	private function addPlaceholderId(id:String, previousId:String, bridge:IEventDispatcher, 
									  placeholder:Object):void
	{
		if (!bridge)
			throw new Error();	// bridge is required.
			
		if (!idToPlaceholder)
			idToPlaceholder = [];
			
		idToPlaceholder[id] = new PlaceholderData(previousId, bridge, placeholder);	
	}
	
	private function removePlaceholderId(id:String):void
	{
		delete idToPlaceholder[id];
	}

	private var currentSandboxEvent:Event;

	/**
	 * dispatch the event to all sandboxes except the specified one
	 */
	public function dispatchEventToSandboxes(event:Event, skip:IEventDispatcher = null, trackClones:Boolean = false):void
	{
		var clone:Event;
		// trace(">>dispatchEventToSandboxes", this, event.type);
		clone = event.clone();
		if (trackClones)
			currentSandboxEvent = clone;
		var parentBridge:IEventDispatcher = sandboxBridgeGroup.parentBridge;
		if (parentBridge && parentBridge != skip)
		{
			parentBridge.dispatchEvent(clone);
		}
		
		var children:Array = sandboxBridgeGroup.getChildBridges();
		for (var i:int = 0; i < children.length; i++)
		{
			if (children[i] != skip)
			{
				// trace("send to child", i, event.type);
				clone = event.clone();
				if (trackClones)
					currentSandboxEvent = clone;
				IEventDispatcher(children[i]).dispatchEvent(clone);
			}
		}
		currentSandboxEvent = null;

		// trace("<<dispatchEventToSandboxes", this, event.type);
	}

	/**
	 * request the parent to add an event listener.
	 */
	private function addEventListenerToSandboxes(type:String, listener:Function, useCapture:Boolean = false, 
				priority:int=0, useWeakReference:Boolean=false, skip:IEventDispatcher = null):void
	{
		// trace(">>addEventListenerToSandboxes", this, type);

		var request:EventListenerRequest = new EventListenerRequest(EventListenerRequest.ADD,
													type, 
													useCapture, 
													priority,
													useWeakReference);
		
		var parentBridge:IEventDispatcher = sandboxBridgeGroup.parentBridge;
		if (parentBridge)
		{
			parentBridge.addEventListener(type, listener, useCapture, priority, useWeakReference);			
		}
		
		var children:Array = sandboxBridgeGroup.getChildBridges();
		for (var i:int; i < children.length; i++)
		{
		 	var childBridge:IEventDispatcher = IEventDispatcher(children[i]);
			childBridge.addEventListener(type, listener, useCapture, priority, useWeakReference);			
		}
		
		dispatchEventToSandboxes(request, skip);
		// trace("<<addEventListenerToSandboxes", this, type);
	}

	/**
	 * request the parent to remove an event listener.
	 */	
	private function removeEventListenerFromSandboxes(type:String, listener:Function, useCapture:Boolean = false):void 
	{
		// trace(">>removeEventListenerToSandboxes", this, type);
		var request:EventListenerRequest = new EventListenerRequest(EventListenerRequest.REMOVE,
																				type, 
																				useCapture);
		var parentBridge:IEventDispatcher = sandboxBridgeGroup.parentBridge;
		if (parentBridge)
			parentBridge.removeEventListener(type, listener, useCapture);
		
		var children:Array = sandboxBridgeGroup.getChildBridges();
		for (var i:int; i < children.length; i++)
		{
			IEventDispatcher(children[i]).removeEventListener(type, listener, useCapture);			
		}
		
		dispatchEventToSandboxes(request);
		// trace("<<removeEventListenerToSandboxes", this, type);
	}

	private function sandboxMouseListener(event:Event):void
	{
		// trace("sandboxMouseListener", this);
		if (event is MarshalMouseEvent)
			return;

		var marshaledEvent:Event = MarshalMouseEvent.marshal(event);
		dispatchEventToSandboxes(marshaledEvent, event.target as IEventDispatcher);

		// ask the sandbox root if it was the original dispatcher of this event
		// if it was then don't dispatch to ourselves because we could have
		// got this event by listening to sandboxRoot ourselves.
		var me:MarshalEvent = new MarshalEvent(MarshalEvent.SYSTEM_MANAGER);
		me.name = "sameSandbox";
		me.value = event;
		getSandboxRoot().dispatchEvent(me);

		if (!me.value)
			dispatchEvent(marshaledEvent);
	}

	private function eventListenerRequestHandler(event:Event):void
	{
		if (event is EventListenerRequest)
			return;

		var eventObj:Object = event;
		if (event.type == EventListenerRequest.ADD)
		{
			if (!eventProxy)
				eventProxy = new EventProxy(this);
			
			// trace(">>eventListenerRequestHandler", this, eventObj.userType);

			var actualType:String = EventUtil.marshalMouseEventMap[eventObj.userType];
			if (actualType)
			{
				addEventListenerToSandboxes(eventObj.userType, sandboxMouseListener,
							eventObj.useCapture, eventObj.priority, eventObj.useWeakReference, event.target as IEventDispatcher);
				if (getSandboxRoot() == this)
					super.addEventListener(actualType, eventProxy.marshalListener,
							eventObj.useCapture, eventObj.priority, eventObj.useWeakReference);
			}
			// trace("<<eventListenerRequestHandler", this, eventObj.userType);
		}
	}
}

}

import flash.display.DisplayObject;
import flash.events.IEventDispatcher;

/**
 * A form that exists in a SystemManager in another sandbox or compiled with
 * a different version of Flex.
 * 
 * An instance of a RemotePopUp is put into the forms array of the top-level 
 * System Manager so the top-level System Manager can manage the form's 
 * activation/deactivation along with any other forms that are displayed.
 */
class RemotePopUp extends Object
{
	/**
	 * Create new RemotePopUp. There are two kinds of remote pop ups. One for trusted
	 * popups and one for untrusted popups. Trusted pop ups pass may pass display objects
	 * and the bridge handle of the form. Untrusted pop ups may only pass a string id and
	 * the bridge handle of the direct child.
	 * 
	 * @param window String if the form is a placeholder for an untrusted pop up. A display
	 * object (SystemManagerProxy) if the form is trusted.
	 * 
	 * @param bridge If the form is trusted, the bridge handle of the source of the form.
	 * If the form is untrusted, the bridge of the direct child of this application that parents
	 * the source of the form. 
	 */
	public function RemotePopUp(window:Object, bridge:Object)
	{
		this.window = window;
  		this.bridge = bridge;
	}
	
	public var window:Object;		// SystemManagerProxy or String id of remote form
	public var bridge:Object;		// bridge of remote form
}

import flash.events.EventDispatcher;
import flash.events.IEventDispatcher;
import flash.events.Event;
import flash.events.MouseEvent;
import mx.events.MarshalMouseEvent;
import mx.utils.EventUtil;
import mx.managers.SystemManager;

/**
 * An object that marshals events to other sandboxes
 */
class EventProxy extends EventDispatcher
{
	private var systemManager:SystemManager;

	public function EventProxy(systemManager:SystemManager)
	{
		this.systemManager = systemManager;
	}

	public function marshalListener(event:Event):void
	{
		if (event is MouseEvent)
		{
			var me:MouseEvent = event as MouseEvent;;
			var mme:MarshalMouseEvent = new MarshalMouseEvent(EventUtil.mouseEventMap[event.type],
				false, false, me.ctrlKey, me.altKey, me.shiftKey, me.buttonDown);
			// trace(">>marshalListener", systemManager, mme.type);
			systemManager.dispatchEventToSandboxes(mme, null, true);
			// trace("<<marshalListener", systemManager);
		}
	}

}

import flash.display.Stage;
import flash.events.MouseEvent;

/**
 * An object that filters stage
 */
class StageEventProxy
{
	private var listener:Function;

	public function StageEventProxy(listener:Function)
	{
		this.listener = listener;
	}

	public function stageListener(event:Event):void
	{
		if (event.target is Stage)
			listener(event);
	}

}

/**
 * Simple class to track placeholders for RemotePopups.
 */
class PlaceholderData extends Object
{
	public function PlaceholderData(id:String, bridge:IEventDispatcher, data:Object)
	{
		this.id = id;
		this.bridge = bridge;
		this.data = data;
}

	public var id:String;				// id of string at this node in the display list
	public var bridge:IEventDispatcher; // bridge to next child application
	public var data:Object;				// either a popup or a bridge to the next application 
}
