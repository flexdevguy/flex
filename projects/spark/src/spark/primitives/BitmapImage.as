////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2003-2006 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package mx.graphics
{
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.DisplayObject;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.geom.Transform;
import flash.utils.getDefinitionByName;

import mx.core.mx_internal;
import mx.events.PropertyChangeEvent;
import mx.filters.BaseFilter;
import mx.filters.IBitmapFilter;
import mx.graphics.BitmapFill;

import mx.graphics.graphicsClasses.GraphicElement;

/**
 *  A BitmapGraphic element defines a rectangular region in its parent element's 
 *  coordinate space, filled with bitmap data drawn from a source file.
 *  
 *  @includeExample examples/BitmapGraphicExample.mxml
 */
public class BitmapGraphic extends GraphicElement
{
    include "../core/Version.as";

    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------

    /**
     *  Constructor. 
     */
    public function BitmapGraphic()
    {
        super();
        
        _fill = new BitmapFill();
    }
    
    private var _fill:BitmapFill;
    
    //--------------------------------------------------------------------------
    //
    //  Properties
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  alwaysNeedsDisplayObject
    //----------------------------------
    
    private var _alwaysNeedsDisplayObject:Boolean = false;
    
    /*
     *  Set this to true to force the Graphic Element to create an underlying Shape
     */
    mx_internal function set alwaysNeedsDisplayObject(value:Boolean):void
    {
        if (value != _alwaysNeedsDisplayObject)
        {
            _alwaysNeedsDisplayObject = value;
            notifyElementLayerChanged();
        }
    }
    
    mx_internal function get alwaysNeedsDisplayObject():Boolean
    {
        return _alwaysNeedsDisplayObject;
    }
    
    //----------------------------------
    //  resizeMode
    //----------------------------------
    /**
     *  The default state.
     */
    protected static const _NORMAL_UINT:uint = 0;

    /**
     *  Repeats the graphic.
     */
    protected static const _REPEAT_UINT:uint = 1;

    /**
     *  Scales the graphic.
     */
    protected static const _SCALE_UINT:uint = 2;

    /**
     *  Converts from the String to the uint
     *  representation of the enum values.
     *  
     *  @param value The String to convert.
     *  
     *  @return The uint representation of the enum values.
     */
    protected static function resizeModeToUINT(value:String):uint
    {
        switch(value)
        {
            case BitmapResizeMode.REPEAT: return _REPEAT_UINT;
            case BitmapResizeMode.SCALE: return _SCALE_UINT;
            default: return _NORMAL_UINT;
        }
    }

    /**
     *  Converts from the uint to the String
     *  representation of the enum values.
     *  
     *  @param value The uint to convert.
     *  
     *  @return The String representation of the enum values.
     */
    protected static function resizeModeToString(value:uint):String
    {
        switch(value)
        {
            case _REPEAT_UINT: return BitmapResizeMode.REPEAT;
            case _SCALE_UINT: return BitmapResizeMode.SCALE;
            default: return BitmapResizeMode.NORMAL;
        }
    }

    /**
     *  @private
     */
    protected var _resizeMode:uint = _REPEAT_UINT;
    
    [Bindable("propertyChange")]
    [Inspectable(category="General")]
    
    /**
     *  The resizeMode determines how the bitmap fills in the dimensions. If you set the value
     *  of this property in a tag, use the string (such as "Repeat"). If you set the value of 
     *  this property in ActionScript, use the constant (such as <code>BitmapResizeMode.NORMAL</code>).
     * 
     *  When set to <code>BitmapResizeMode.NORMAL</code> ("Normal"), the bitmap
     *  ends at the edge of the region.
     * 
     *  When set to <code>BitmapResizeMode.REPEAT</code> ("Repeat"), the bitmap 
     *  repeats to fill the region.
     *
     *  When set to <code>BitmapResizeMode.SCALE</code> ("Scale"), the bitmap
     *  stretches to fill the region.
     * 
     *  @default <code>BitmapResizeMode.NORMAL</code>
     */
    public function get resizeMode():String 
    {
        return resizeModeToString(_resizeMode);
    }
    
    /**
     *  @private
     */
    public function set resizeMode(mode:String):void
    {
        var value:uint = resizeModeToUINT(mode);
        var oldValue:uint = _resizeMode;
        var oldRepeat:Boolean = repeat;
        if (value != oldValue)
        {
            _resizeMode = value;
            invalidateDisplayList();
            dispatchPropertyChangeEvent("resizeMode", oldValue, value);
        }
        if (repeat != oldRepeat)
        {
            dispatchPropertyChangeEvent("repeat", oldValue, repeat);
        } 
    }

    //----------------------------------
    //  repeat
    //----------------------------------

    [Bindable("propertyChange")]
    [Inspectable(category="General")]

    /**
     *  Whether the bitmap is repeated to fill the area. Set to <code>true</code> to cause 
     *  the fill to tile outward to the edges of the filled region. 
     *  Set to <code>false</code> to end the fill at the edge of the region.
     *
     *  @default true
     */
    public function get repeat():Boolean 
    {
        return _resizeMode == _REPEAT_UINT;
    }
    
    /**
     *  @private
     */
    public function set repeat(value:Boolean):void
    {
        var oldValue:Boolean = repeat;
        
        if (value != oldValue)
        {
            resizeMode = value ? BitmapResizeMode.REPEAT : BitmapResizeMode.NORMAL;  
            invalidateDisplayList();
            dispatchPropertyChangeEvent("repeat", oldValue, value);
        }
    }

    //----------------------------------
    //  source
    //----------------------------------

    [Bindable("propertyChange")]
    [Inspectable(category="General")]

    /**
     *  The source used for the bitmap fill. The fill can render from various graphical 
     *  sources, including the following: 
     *  <ul>
     *   <li>A Bitmap or BitmapData instance.</li>
     *   <li>A class representing a subclass of DisplayObject. The BitmapFill instantiates 
     *       the class and creates a bitmap rendering of it.</li>
     *   <li>An instance of a DisplayObject. The BitmapFill copies it into a Bitmap for filling.</li>
     *   <li>The name of a subclass of DisplayObject. The BitmapFill loads the class, instantiates it, 
     *       and creates a bitmap rendering of it.</li>
     *  </ul>
     *  
     *  <p>If you use an image file for the source, it can be of type PNG, GIF, or JPG.</p>
     *  
     *  <p>To specify an image as a source, you must use the &#64;Embed directive, as the following example shows:
     *  <pre>
     *  source="&#64;Embed('&lt;i&gt;image_location&lt;/i&gt;')"
     *  </pre>
     *  </p>
     *  
     *  <p>The image location can be a URL or file reference. If it is a file reference, its location is relative to
     *  the location of the file that is being compiled.</p>
     *  
     *  <p>The BitmapGraphic class is designed to work with embedded images, not with images that are 
     *  loaded at run time. You can use the Image control to load the image at run time,
     *  and then assign the Image control to the value of the BitmapGraphic's <code>source</code> property.</p>
     *  
     *  @see flash.display.Bitmap
     *  @see flash.display.BitmapData
     *  @see mx.graphics.BitmapFill
     */
    public function get source():Object
    {
        return _fill.source;
    }
    
    /**
     *  @private
     */
    public function set source(value:Object):void
    {
        var oldValue:Object = _fill.source;
        
        if (value != oldValue)
        {
            var bitmapData:BitmapData;
            var tmpSprite:DisplayObject;
            
            // This code stolen from BitmapFill. The only change is to make the BitmapData transparent.
            if (value is Class)
            {
                var cls:Class = Class(value);
                tmpSprite = new cls();
            }
            else if (value is BitmapData)
            {
                bitmapData = value as BitmapData;
            }
            else if (value is Bitmap)
            {
                bitmapData = value.bitmapData;
            }
            else if (value is DisplayObject)
            {
                tmpSprite = value as DisplayObject;
            }
            else if (value is String)
            {
                var tmpClass:Class = Class(getDefinitionByName(String(value)));
                tmpSprite = new tmpClass();
            }
            else
            {
                return;
            }
            
            if (!bitmapData && tmpSprite)
            {
                bitmapData = new BitmapData(tmpSprite.width, tmpSprite.height, true, 0);
                bitmapData.draw(tmpSprite, new Matrix());
            }       
            
            _fill.source = bitmapData;
            dispatchPropertyChangeEvent("source", oldValue, value);
            invalidateSize();
            invalidateDisplayList();
        }
    }
    
    //----------------------------------
    //  smooth
    //----------------------------------

    private var _smooth:Boolean = false;

    [Inspectable(category="General")]   
    
    /**
     *  @copy flash.display.GraphicsBitmapFill#smooth
     *
     *  @default false
     */
    public function set smooth(value:Boolean):void
    {
        if (value != _smooth)
        {
            _smooth = value;
            invalidateDisplayList();
        }
    }
    
    /**
     *  @private
     */
    public function get  smooth():Boolean
    {
        return _smooth;
    }
    
    //--------------------------------------------------------------------------
    //
    //  IGraphicElement Implementation
    //
    //--------------------------------------------------------------------------
    
    /**
     *  @inheritDoc
     */
    override protected function measure():void
    {
        measuredWidth = source ? source.width : 0;
        measuredHeight = source ? source.height : 0;
    }
    
    /**
     *  @inheritDoc
     */
    override protected function updateDisplayList(unscaledWidth:Number, 
                                                  unscaledHeight:Number):void
    {
        /* if (!displayObject || !(displayObject is Sprite))
            return; */

        if (!source)
            return;
            
        if (displayObject is Sprite)
            Sprite(displayObject).graphics.clear();
        else if (displayObject is Shape)
            Shape(displayObject).graphics.clear();

        var g:Graphics = Sprite(drawnDisplayObject).graphics;
        
        g.lineStyle();
        _fill.offsetX = drawX;
        _fill.offsetY = drawY;
        _fill.smooth = smooth;
        _fill.repeat = false;
        _fill.scaleX = 1;
        _fill.scaleY = 1;
        var fillWidth:Number;
        var fillHeight:Number;
    
        switch(_resizeMode)
        {
            case _NORMAL_UINT:
                fillWidth = Math.min(unscaledWidth, source.width);
                fillHeight = Math.min(unscaledHeight, source.height);
            break;

            case _REPEAT_UINT:
                if (source)
                {
                    _fill.repeat = true;
                    fillWidth = unscaledWidth;
                    fillHeight = unscaledHeight;
                }    
            break;

            case _SCALE_UINT:
                if (source)
                {
                    _fill.scaleX = unscaledWidth / source.width;
                    _fill.scaleY = unscaledHeight / source.height;
                    fillWidth = source.width;
                    fillHeight = source.height;
                }
            break;
        }

        _fill.begin(g, new Rectangle(fillWidth, fillHeight));
        g.drawRect(drawX, drawY, unscaledWidth, unscaledHeight);
        _fill.end(g);
    }
    
    //--------------------------------------------------------------------------
    //
    //  IAssignableDisplayObject Implementation
    //
    //--------------------------------------------------------------------------

}

}
