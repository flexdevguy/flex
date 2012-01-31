////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2010 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package spark.components.gridClasses
{
import flash.events.Event;
import flash.events.EventDispatcher;

import mx.collections.SortField;
import mx.core.ClassFactory;
import mx.core.IFactory;
import mx.core.mx_internal;
import mx.events.CollectionEvent;
import mx.events.CollectionEventKind;
import mx.events.PropertyChangeEvent;
import mx.utils.ObjectUtil;

import spark.components.Grid;
import spark.components.gridClasses.DefaultGridItemEditor;
import spark.components.gridClasses.GridSortField;

use namespace mx_internal;

/**
 *  The GridColumn class defines a column of a Spark grid control,
 *  such as the Spark DataGrid or Grid control.
 *  Each data provider item for the control corresponds to one row of the grid. 
 *  The GridColumn class specifies the field of the data provider item 
 *  whose value is to be displayed in the column.
 *  It also specifies the item renderer used to display that value, the item editor
 *  used to change the value, and other properties of the column.
 *
 *  @see spark.components.Grid
 *  @see spark.components.DataGrid
 * 
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 2.5
 *  @productversion Flex 4.5
 */   
public class GridColumn extends EventDispatcher
{
    include "../../core/Version.as";
    
    //--------------------------------------------------------------------------
    //
    //  Class constants
    //
    //--------------------------------------------------------------------------
    
    /**
     *  The return value for the <code>itemToLabel()</code> or 
     *  <code>itemToDataTip()</code> method  if resolving the corresponding 
     *  property name (path) fails.  
     *  The value of this constant is a single space String: <code>" "</code>.
     * 
     *  @see #itemToLabel
     *  @see #itemToDataTip
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public static const ERROR_TEXT:String = new String(" ");
    
    //--------------------------------------------------------------------------
    //
    //  Class variables and methods
    //
    //--------------------------------------------------------------------------
    
    //----------------------------------
    //  defaultItemEditorFactory
    //----------------------------------
    
    private static var _defaultItemEditorFactory:IFactory;
    
    /**
     *  @private
     */
    mx_internal static function get defaultItemEditorFactory():IFactory
    {
        if (!_defaultItemEditorFactory)
            _defaultItemEditorFactory = new ClassFactory(DefaultGridItemEditor);
        return _defaultItemEditorFactory;
    }
    
    /**
     *  @private
     *  A default compare function for sorting if the dataField is a complex path.
     */
    private static function dataFieldPathSortCompare(obj1:Object, obj2:Object, column:GridColumn):int
    {
        if (!obj1 && !obj2)
            return 0;
        
        if (!obj1)
            return 1;
        
        if (!obj2)
            return -1;
        
        const dataFieldPath:Array = column.dataField.split(".");
        var obj1String:String = deriveDataFromPath(obj1, dataFieldPath);
        var obj2String:String = deriveDataFromPath(obj2, dataFieldPath);
        
        if ( obj1String < obj2String )
            return -1;
        
        if ( obj1String > obj2String )
            return 1;
        
        return 0;
    }

    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------
    
    /**
     *  Constructor. 
     * 
     *  @param columnName Initial value for the <code>dataField</code> and 
     *     <code>headerText</code> properties. 
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function GridColumn(columnName:String = null)
    {
        super();
        
        if (columnName)
            dataField = headerText = columnName;
    }
    
    //--------------------------------------------------------------------------
    //
    //  Properties
    //
    //--------------------------------------------------------------------------
    
    //----------------------------------
    //  grid
    //----------------------------------
    
    private var _grid:Grid = null;
    
    /** 
     *  @private
     *  Set by the Grid when this column is added to grid.columns, set
     *  to null when the column is removed.
     */
    mx_internal function setGrid(value:Grid):void
    {
        if (_grid == value)
            return;
        
        _grid = value;
        dispatchChangeEvent("gridChanged");        
    }

    [Bindable("gridChanged")]    
    
    /**
     *  The Grid object associated this whose column.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get grid():Grid
    {
        return _grid;
    }
    
    //----------------------------------
    //  columnIndex
    //----------------------------------
    
    private var _columnIndex:int = -1;
    
    /** 
     *  @private
     *  Set by the Grid when this column is added to the grid.columns, set
     *  to -1 when the column is removed.
     */
    mx_internal function setColumnIndex(value:int):void
    {
        if (_columnIndex == value)
            return;
        
        _columnIndex = value;
        dispatchChangeEvent("columnIndexChanged");        
    }
    
    [Bindable("columnIndexChanged")]    
    
    /**
     *  The position of this column in the grid's column list, 
     *  or -1 if this column's grid is null.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get columnIndex():int
    {
        return _columnIndex;
    }   
    
    //----------------------------------
    //  dataField
    //----------------------------------
    
    private var _dataField:String = null;
    private var dataFieldPath:Array = [];
    
    [Bindable("dataFieldChanged")]    
    
    /**
     *  The name of the field or property in the data provider item associated 
     *  with the column. 
     *  Each GridColumn requires this property or 
     *  the <code>labelFunction</code> property to be set 
     *  to calculate the displayable text for the item renderer.
     *  If the <code>dataField</code>
     *  and <code>labelFunction</code> properties are set, 
     *  the data is displayed using the <code>labelFunction</code> and sorted
     *  using the <code>dataField</code>.  
     *
     *  <p>This value of this property is not necessarily the String that 
     *  is displayed in the column header.  This property is
     *  used only to access the data in the data provider. 
     *  For more information, see the <code>headerText</code> property.</p>
     * 
     *  <p>If the column or its grid specifies a <code>labelFunction</code>, 
     *  then the dataField is not used.</p>
     *      
     *  @default null
     * 
     *  @see #itemToLabel
     *  @see #labelFunction
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get dataField():String
    {
        return _dataField;
    }
    
    /**
     *  @private
     */
    public function set dataField(value:String):void
    {
        if (_dataField == value)
            return;
        
        _dataField = value;
        
        if (value == null)
        {
            dataFieldPath = [];
        }
        else if (value.indexOf( "." ) != -1) 
        {
            dataFieldPath = value.split(".");
        }
        else
        {
            dataFieldPath = [value];
        }
        
        invalidateGrid();
        if (grid)
            grid.clearGridLayoutCache(true);
        
        dispatchChangeEvent("dataFieldChanged");
    }
    
    //----------------------------------
    //  dataTipField
    //----------------------------------
    
    private var _dataTipField:String = null;
    
    [Bindable("dataTipFieldChanged")]    
    
    /**
     *  The name of the field in the data provider to display as the datatip. 
     *  By default, if <code>showDataTips</code> is <code>true</code>,
     *  the associated grid control looks for a property named 
     *  <code>label</code> on each data provider item and displays it.
     *  However, if the data provider does not contain a <code>label</code>
     *  property, you can set the <code>dataTipField</code> property to
     *  specify a different property name.  
     *  For example, you could set the value to "FullName" when a user views a
     *  set of people's names included from a database.
     *
     *  <p><code>GridColumn.dataTipField</code> takes precedence over this property.</p>
     * 
     *  <p>If this column or its grid specifies a value for the 
     *  <code>dataTipFunction</code> property, then the
     *  <code>dataTipField</code> property is ignored.</p>
     * 
     *  @default null
     *  @see #dataTipFunction
     *  @see #itemToDataTip
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get dataTipField():String
    {
        return _dataTipField;
    }
    
    /**
     *  @private
     */
    public function set dataTipField(value:String):void
    {
        if (_dataTipField == value)
            return;
        
        _dataTipField = value;
        
        if (grid)
            grid.invalidateDisplayList();
        
        dispatchChangeEvent("dataTipFieldChanged");
    }
    
    //----------------------------------
    //  dataTipFunction
    //----------------------------------
    
    private var _dataTipFunction:Function = null;
    
    [Bindable("dataTipFunctionChanged")]
    
    /**
     *  Specifies a callback function to run on each item of the data provider 
     *  to determine its dataTip.
     *  This property is used by the <code>itemToDataTip</code> method.
     * 
     *  <p>By default, if <code>showDataTips</code> is <code>true</code>,
     *  the column looks for a property named <code>label</code>
     *  on each data provider item and displays it as its dataTip.
     *  However, some data providers do not have a <code>label</code> property 
     *  nor do they have another property that you can use for displaying data 
     *  in the rows.
     *  For example, you might have a data provider that contains a lastName 
     *  and firstName fields, but you want to display full names as the dataTip.
     *  You can specify a function to the <code>dataTipFunction</code> property 
     *  that returns a single String containing the value of both fields. You 
     *  can also use the <code>dataTipFunction</code> property for handling 
     *  formatting and localization.</p>
     * 
     *  <p>The dataTipFunction's signature must match the following:
     * 
     *  <pre>dataTipFunction(item:Object, column:GridColumn):String</pre>
     *
     *  The <code>item</code> parameter is the data provider item for an entire row.  
     *  The second parameter is this column object.</p>
     *
     *  <p>A typical function might concatenate an item's firstName and
     *  lastName properties, or do some custom formatting on a Date value
     *  property.</p>
     *
     * 
     *  @default null
     * 
     *  @see #itemToDataTip
     *  @see #dataTipField
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get dataTipFunction():Function
    {
        return _dataTipFunction;
    }
    
    /**
     *  @private
     */
    public function set dataTipFunction(value:Function):void
    {
        if (_dataTipFunction == value)
            return;
        
        _dataTipFunction = value;
        
        if (grid)
            grid.invalidateDisplayList();
        
        dispatchChangeEvent("dataTipFunctionChanged");
    }
    
    //----------------------------------
    //  editable
    //----------------------------------
    
    private var _editable:Boolean = true;
    
    [Bindable("editableChanged")]
    [Inspectable(category="General")]
    
    /**
     *  Indicates whether the items in the column are editable.
     *  If <code>true</code>, and the associated grid's <code>editable</code>
     *  property is also <code>true</code>, the items in a column are 
     *  editable and can be individually edited
     *  by clicking on a selected item, or by navigating to the item and 
     *  pressing the F2 key.
     *
     *  @default true
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get editable():Boolean
    {
        return _editable;
    }
    
    /**
     *  @private
     */
    public function set editable(value:Boolean):void
    {
        if (_editable == value)
            return;
        
        _editable = value;
        dispatchChangeEvent("editableChanged");
    }
    
    //----------------------------------
    //  headerRenderer
    //----------------------------------
    
    private var _headerRenderer:IFactory = null;
    
    [Bindable("headerRendererChanged")]
    
    /**
     *  The class factory for the IGridItemRenderer class used as 
     *  the header for this column.  
     *  If unspecified, the DataGrid controls's <code>columnHeaderGroup</code>
     *  skin part defines the default header renderer.
     * 
     *  @default null
     *
     *  @see #headerText
     *  @see IGridItemRenderer
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get headerRenderer():IFactory
    {
        return _headerRenderer;
    }
    
    /**
     *  @private
     */
    public function set headerRenderer(value:IFactory):void
    {
        if (_headerRenderer == value)
            return;
        
        _headerRenderer = value;

        if (grid)
            grid.invalidateDisplayList();
        
        dispatchChangeEvent("headerRendererChanged");
    }
    
    //----------------------------------
    //  headerText
    //----------------------------------
    
    private var _headerText:String;
    
    [Bindable("headerTextChanged")]
    
    /**
     *  Text for the header of this column. 
     *  By default, the associated grid control uses the value of 
     *  the <code>dataField</code> property  as the header text.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get headerText():String
    {
        return (_headerText != null) ? _headerText : ((dataField) ? dataField : "");
    }
    
    /**
     *  @private
     */
    public function set headerText(value:String):void
    {
        _headerText = value;
        
        if (grid)
            grid.invalidateDisplayList();

        dispatchChangeEvent("headerTextChanged");
    }
   
    //----------------------------------
    //  imeMode
    //----------------------------------
    
    private var _imeMode:String = null;
    
    [Inspectable(environment="none")]
    
    /**
     *  @copy spark.components.gridClasses.GridItemEditor#imeMode
     *
     *  @see flash.system.IMEConversionMode
     *
     *  @default null
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get imeMode():String
    {
        return _imeMode;
    }
    
    /**
     *  @private
     */
    public function set imeMode(value:String):void
    {
        _imeMode = value;
    }
    
    //----------------------------------
    //  itemEditor
    //----------------------------------
    
    private var _itemEditor:IFactory = null;
    
    [Bindable("itemEditorChanged")]
    
    /**
     *  A class factory for IGridItemEditor class used to edit individual 
     *  grid cells in this column.
     *  If this property is null, and the column grid's owner is a DataGrid control, 
     *  then the value of the DataGrid control's <code>itemEditor</code> property is used.   
     *  If no item editor is specified by the DataGrid control, 
     *  then use the DefaultGridItemEditor class.
     * 
     *  <p>The default item editor is the DefaultGridItemEditor class, 
     *  which lets you edit a simple text field. 
     *  You can create custom item renderers by creating a subclass of the GridItemEditor class.
     *  Your custom item editor can write data to the entire row of the grid
     *  to define more complex editor. </p>
     * 
     *  @default null
     *
     *  @see spark.components.gridClasses.DefaultGridItemEditor
     *  @see spark.components.gridClasses.GridItemEditor
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get itemEditor():IFactory
    {
        return _itemEditor;
    }
    
    /**
     *  @private
     */
    public function set itemEditor(value:IFactory):void
    {
        if (_itemEditor == value)
            return;
        
        _itemEditor = value;
        
        dispatchChangeEvent("itemEditorChanged");
    }

    //----------------------------------
    //  itemRenderer
    //----------------------------------

    private var _itemRenderer:IFactory = null;
    
    [Bindable("itemRendererChanged")]
    
    /**
     *  The class factory for the IGridItemRenderer class used to 
     *  render individual grid cells.  
     *  If not specified, use the value of the <code>itemRenderer</code> 
     *  property from the associated grid control.
     * 
     *  <p>The default item renderer is the DefaultGridItemRenderer class, 
     *  which displays the data item as text. 
     *  You can create custom item renderers by creating a subclass of the GridItemRenderer class.
     *  Your custom item renderer can access the data from the entire row of the grid
     *  to define more complex visual representation of the cell. </p>
     * 
     *  <p>The default value is the value of the <code>itemRenderer</code> 
     *  property from the associated grid control, or null.</p>
     *
     *  @see #dataField 
     *  @see spark.skins.spark.DefaultGridItemRenderer
     *  @see spark.components.gridClasses.GridItemRenderer
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get itemRenderer():IFactory
    {
        return (_itemRenderer) ? _itemRenderer : grid.itemRenderer;
    }
    
    /**
     *  @private
     */
    public function set itemRenderer(value:IFactory):void
    {
        if (_itemRenderer == value)
            return;
        
        _itemRenderer = value;

        invalidateGrid();
        if (grid)
            grid.clearGridLayoutCache(true);
        
        dispatchChangeEvent("itemRendererChanged");
    }
    
    //----------------------------------
    //  itemRendererFunction
    //----------------------------------
    
    private var _itemRendererFunction:Function = null;
    
    [Bindable("itemRendererFunctionChanged")]
    
    /**
     *  If specified, the value of this property must be an idempotent function 
     *  that returns an item renderer IFactory based on its data provider item 
     *  and column parameters.  
     *  Specifying a value to the <code>itemRendererFunction</code> property
     *  makes it possible to use more than one item renderer in this column.
     * 
     *  <p>The function specified to the <code>itemRendererFunction</code> property 
     *  must have the following signature:</p>
     *
     *  <pre>itemRendererFunction(item:Object, column:GridColumn):IFactory</pre>
     *
     *  <p>The <code>item</code> parameter is the data provider item for an entire row.  
     *  The second parameter is this column object.</p> 
     * 
     *  <p>Shown below is an example of an item renderer function:</p>
     *  <pre>
     *  function myItemRendererFunction(item:Object, column:GridColumn):IFactory
     *  {
     *      return (item is Array) ? myArrayItemRenderer : myItemRenderer;
     *  }
     *  </pre>
     *  
     *  @default null
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get itemRendererFunction():Function
    {
        return _itemRendererFunction;
    }
    
    /**
     *  @private
     */
    public function set itemRendererFunction(value:Function):void
    {
        if (_itemRendererFunction == value)
            return;

        _itemRendererFunction = value;
        
        invalidateGrid();
        if (grid)
            grid.clearGridLayoutCache(true);
        
        dispatchChangeEvent("itemRendererFunctionChanged");
    }
    
    //----------------------------------
    //  labelFunction
    //----------------------------------
    
    private var _labelFunction:Function = null;
    
    [Bindable("labelFunctionChanged")]
    
    /**
     *  An idempotent function that converts a data provider item into a column-specific string
     *  that's used to initialize the item renderer's <code>label</code> property.
     * 
     *  <p>You can use a label function to combine the values of several data provider items
     *  into a single string.  
     *  If specified, this property is used by the 
     *  <code>itemToLabel()</code> method, which computes the value of each item 
     *  renderer's <code>label</code> property in this column.</p>
     *
     *  <p>The function specified to the <code>labelFunction</code> property 
     *  must have the following signature:</p>
     *
     *  <pre>labelFunction(item:Object, column:GridColumn):String</pre>
     *
     *  <p>The <code>item</code> parameter is the data provider item for an entire row.  
     *  The second parameter is this column object.</p>
     *
     *  <p>A typical label function could concatenate the firstName and
     *  lastName properties of the data provider item , 
     *  or do some custom formatting on a Date value property.</p>
     * 
     *  @default null
     * 
     *  @see #itemToLabel
     *  @see #dataField
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get labelFunction():Function
    {
        return _labelFunction;
    }
    
    /**
     *  @private
     */
    public function set labelFunction(value:Function):void
    {
        if (_labelFunction == value)
            return;

        _labelFunction = value;
        
        invalidateGrid();
        if (grid)
            grid.clearGridLayoutCache(true);
        
        dispatchChangeEvent("labelFunctionChanged");
    }
    
    //----------------------------------
    //  width
    //---------------------------------- 
    
    private var _width:Number = NaN;
    
    [Bindable("widthChanged")]    
    
    /**
     *  The width of this column in pixels. 
     *  If specified, the grid's layout ignores its
     *  <code>typicalItem</code> property and this column's 
     *  <code>minWidth</code> and <code>maxWidth</code> properties.
     * 
     *  @default NaN
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get width():Number
    {
        return _width;
    }
    
    /**
     *  @private
     */
    public function set width(value:Number):void
    {
        if (_width == value)
            return;
        
        _width = value;
        
        invalidateGrid();
        
        // Reset content size so scroller's viewport can be resized.  There
        // is loop-prevention logic in the scroller which may not allow the
        // width/height to be reduced if there are automatic scrollbars.
        // See ScrollerLayout/measure().
        /*
        if (grid)
            grid.setContentSize(0, 0);
        */
        
        dispatchChangeEvent("widthChanged");
    }
    
    //----------------------------------
    //  minWidth
    //---------------------------------- 
    
    private var _minWidth:Number = 20;
    
    [Bindable("minWidthChanged")]    
    
    /**
     *  The minimum width of this column in pixels. 
     *  If specified, the grid's layout makes the column's layout 
     *  width the larger of the width of the <code>typicalItem</code> and 
     *  the <code>minWidth</code>.
     *  If this column is resizable, this property limits how small 
     *  the user can make this column.
     *  Setting this property does not change the <code>width</code> 
     *  or <code>maxWidth</code> properties.
     *  
     *  @default 20
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get minWidth():Number
    {
        return _minWidth;
    }
    
    /**
     *  @private
     */
    public function set minWidth(value:Number):void
    {
        if (_minWidth == value)
            return;
        
        _minWidth = value;
        
        invalidateGrid();

        // Reset content size so scroller's viewport can be resized.  There
        // is loop-prevention logic in the scroller which may not allow the
        // width/height to be reduced if there are automatic scrollbars.
        // See ScrollerLayout/measure().
        if (grid)
            grid.setContentSize(0, 0);
        
        dispatchChangeEvent("minWidthChanged");
    }    
       
    //----------------------------------
    //  maxWidth
    //---------------------------------- 
    
    private var _maxWidth:Number = NaN;
    
    [Bindable("maxWidthChanged")]
    
    /**
     *  The maximum width of this column in pixels. 
     *  If specified, the grid's layout makes the column's layout width the 
     *  smaller of the width of the <code>typicalItem</code> and the <code>maxWidth</code>.
     *  If this column is resizable, this property limits how wide the user can make this column.
     *  Setting this property does not change the <code>width</code> 
     *  or <code>minWidth</code> properties.
     *
     *  @default NaN
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get maxWidth():Number
    {
        return _maxWidth;
    }
    
    /**
     *  @private
     */
    public function set maxWidth(value:Number):void
    {
        if (_maxWidth == value)
            return;
        
        _maxWidth = value;
        
        invalidateGrid();

        // Reset content size so scroller's viewport can be resized.  There
        // is loop-prevention logic in the scroller which may not allow the
        // width/height to be reduced if there are automatic scrollbars.
        // See ScrollerLayout/measure().
        if (grid)
            grid.setContentSize(0, 0);
        
        dispatchChangeEvent("maxWidthChanged");
    }
    
    //----------------------------------
    //  rendererIsEditable
    //----------------------------------
    
    private var _rendererIsEditable:Boolean = false;
    
    [Bindable("rendererIsEditableChanged")]
    
    /**
     *  Determines whether any of the item renderer's controls are editable.
     *  If the column is editable, the focusable controls in the item renderer
     *  are given keyboard focus when the user starts editing the item
     *  renderer.
     * 
     *  <p>By setting this property to <code>true</code>, you take responsibility for 
     *  validating and saving input collected by the item renderer.  
     *  If the item renderer contains an override of the <code>IGridItemRenderer.prepare()</code> method, 
     *  then you must ensure that unsaved input field changes are not overwritten.   
     *  For example, <code>rendererIsEditable</code> is <code>true</code>  
     *  and the renderer contains a single TextInput element that displays
     *  the value of <code>data.myDataField</code>.
     *  If the renderer's <code>prepare()</code> method sets the TextInput control's
     *  <code>text</code> property, then the <code>prepare()</code> method must 
     *  not set the <code>text</code> property when there are pending changes.</p>
     * 
     *  <p>TBD: example code or link.</p>
     * 
     *  @default false
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get rendererIsEditable():Boolean
    {
        return _rendererIsEditable;
    }
    
    /**
     *  @private
     */
    public function set rendererIsEditable(value:Boolean):void
    {
        if (_rendererIsEditable == value)
            return;
        
        _rendererIsEditable = value;
        dispatchChangeEvent("rendererIsEditableChanged");
    }
    
    //----------------------------------
    //  resizable
    //----------------------------------
    
    private var _resizable:Boolean = true;
    
    [Bindable("resizableChanged")]   
    [Inspectable(category="General")]
    
    /**
     *  Indicates whether the user is allowed to resize
     *  the width of the column.
     *  If <code>true</code>, and the <code>resizableColumns</code> property of 
     *  the associated grid is also <code>true</code>, the user can drag 
     *  the grid lines between the column headers to resize the column. 
     * 
     *  @default true
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get resizable():Boolean
    {
        return _resizable;
    }
    
    /**
     *  @private
     */
    public function set resizable(value:Boolean):void
    {
        if (_resizable == value)
            return;
        
        _resizable = value;
        dispatchChangeEvent("resizableChanged");
    }
    
    //----------------------------------
    //  showDataTips
    //----------------------------------
    
    private var _showDataTips:* = undefined;
    
    [Bindable("showDataTipsChanged")]  
    
    /**
     *  Indicates whether the datatips are shown in the column.
     *  If <code>true</code>, datatips are displayed for text in the rows. 
     *  Datatips are tooltips designed to show the text that is too long for the row.   
     * 
     *  <p>If this property's value is undefined, the default, then the associated 
     *  grid's <code>showDataTips</code> property determines if datatips are shown.   
     *  If this property is set, the grid's <code>showDataTips</code> property is ignored.</p>
     * 
     *  @default undefined
     * 
     *  @see #getShowDataTips
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get showDataTips():*
    {
        return _showDataTips;
    }
    
    /**
     *  @private
     */
    public function set showDataTips(value:*):void
    {
        if (_showDataTips === value)
            return;

        _showDataTips = value;
        
        if (grid)
            grid.invalidateDisplayList();
        
        dispatchChangeEvent("showDataTipsChanged");        
    }
    
    /**
     *  @private
     */
    mx_internal function getShowDataTips():Boolean
    {
        return (showDataTips === undefined) ? grid && grid.showDataTips : showDataTips;    
    }
    
    //----------------------------------
    //  sortable
    //----------------------------------
    
    private var _sortable:Boolean = true;
    
    [Bindable("sortableChanged")]
    [Inspectable(category="General")]
    
    /**
     *  If <code>true</code>, and if the grid's data provider is an ICollectionView,
     *  and if the associated grid's <code>sortableColumns</code> property is <code>true</code>,
     *  then this column supports interactive sorting. 
     *  Typically the column's header handles mouse clicks by setting the data provider's 
     *  <code>sort</code> property to a Sort object whose SortField is this column's <code>dataField</code>.
     *  
     *  <p>If the data provider is not an ICollectionView, then this property has no effect.</p>
     *  
     *  @default true
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get sortable():Boolean
    {
        return _sortable;
    }
    
    /**
     *  @private
     */
    public function set sortable(value:Boolean):void
    {
        if (_sortable == value)
            return;
        
        _sortable = value;
        
        dispatchChangeEvent("sortableChanged");        
    }
    
    //----------------------------------
    //  sortCompareFunction
    //----------------------------------
    
    private var _sortCompareFunction:Function;
    
    [Bindable("sortCompareFunctionChanged")]
    [Inspectable(category="Advanced")]
    
    /**
     *  The function that compares two elements during a sort of on the
     *  data elements of this column.
     *  If you specify a value of the <code>labelFunction</code> property,
     *  you typically also provide a <code>sortCompareFunction</code>.
     *
     *  <p>The sortCompareFunction's signature must match the following:</p>
     *
     *  <pre>sortCompareFunction(obj1:Object, obj2:Object, column:GridColumn):int</pre>
     * 
     *  <p>The function should return a value based on the comparison
     *  of the objects: </p>
     *  <ul>
     *    <li>-1 if obj1 should appear before obj2 in ascending order. </li>
     *    <li>0 if obj1 = obj2. </li>
     *    <li>1 if obj1 should appear after obj2 in ascending order.</li>
     *  </ul>
     *  
     *  <p>The function may use the column parameter to write generic
     *  compare functions.</p>
     * 
     *  <p><strong>Note:</strong> The <code>obj1</code> and
     *  <code>obj2</code> parameters are entire data provider elements and not
     *  just the data for the item.</p>
     * 
     *  <p>If the dataProvider is not an ICollectionView, then this property has no effect.</p>
     *  
     *  @default null
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get sortCompareFunction():Function
    {
        return _sortCompareFunction;
    }
    
    /**
     *  @private
     */
    public function set sortCompareFunction(value:Function):void
    {
        if (_sortCompareFunction == value)
            return;
        
        _sortCompareFunction = value;
        
        dispatchChangeEvent("sortCompareFunctionChanged");
    }
    
    //----------------------------------
    //  sortDescending
    //----------------------------------
    
    private var _sortDescending:Boolean = false;
    
    [Bindable("sortDescendingChanged")]
    
    /**
     *  If <code>true</code>, this column is sorted in descending order. 
     *  For example, if the column's <code>dataField</code> contains a numeric value, 
     *  then the first row would be the one with the largest value
     *  for this column. 
     *
     *  <p>Setting this property does not start a sort; it only sets the sort direction.
     *  When the <code>dataProvider.refresh()</code> method is called, the sort is performed.</p>
     * 
     *  <p>If the data provider is not an ICollectionView, then this property has no effect.</p>
     * 
     *  @default false;
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get sortDescending():Boolean
    {
        return _sortDescending;
    }
    
    /**
     *  @private
     */
    public function set sortDescending(value:Boolean):void
    {
        if (_sortDescending == value)
            return;
        
        _sortDescending = value;
        
        dispatchChangeEvent("sortDescendingChanged");
    }
    
    //----------------------------------
    //  sortField
    //----------------------------------
    
    /**
     *  Returns a SortField that can be used to sort a collection by this
     *  column's <code>dataField</code>.
     *  
     *  <p>If the <code>sortCompareFunction</code> property is defined,
     *  the SortField's compare function is assigned to a closure around
     *  the <code>sortCompareFunction</code> that uses the right signature
     *  for the SortField and captures this column.</p>
     * 
     *  <p>If the <code>sortCompareFunction</code> property is not defined
     *  and the <code>dataField</code> is complex, then the SortField's
     *  compare function is assigned to a closure around a default compare
     *  function that handles the complex <code>dataField</code>.</p>
     *
     *  <p>If the <code>sortCompareFunction</code> and 
     *  <code>dataField</code> properties are not defined, but the
     *  <code>labelFunction</code> property is defined, then it assigns the 
     *  <code>compareFunction</code> to a closure that does a basic string compare 
     *  on the <code>labelFunction</code> applied to the data objects.</p>
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get sortField():SortField
    {
        const column:GridColumn = this;
        const isComplexDataField:Boolean = dataFieldPath.length > 1;
        
        // A complex dataField requires a GridSortField for the DataGrid
        // to reverse a previous sort on this column by matching dataFieldPath
        // to the dataField.
        // TODO (klin): Might be fixed in Spark Sort. The only reason this is
        // required is because MX Sort RTEs when the dataField doesn't exist on the
        // data object even though a sortCompareFunction is defined.
        var sortField:SortField;
        if (isComplexDataField)
        {
            sortField = new GridSortField();
            GridSortField(sortField).dataFieldPath = dataField;
        }
        else
        {
            sortField = new SortField(dataField);
        }
        
        var cF:Function = null;
        if (_sortCompareFunction != null)
        {
            cF = function (a:Object, b:Object):int
            { 
                return _sortCompareFunction(a, b, column);
            };
        }
        else
        {
            // If no sortCompareFunction is specified, there are defaults for
            // two special cases: complex dataFields and labelFunctions without dataFields.
            
            if (isComplexDataField)
            {
                // use custom compare function for a complex dataField if one isn't provided.
                cF = function (a:Object, b:Object):int
                { 
                    return dataFieldPathSortCompare(a, b, column);
                };
            }
            else if (dataField == null && _labelFunction != null)
            {
                // use basic string compare on the labelFunction results
                cF = function (a:Object, b:Object):int
                { 
                    return ObjectUtil.stringCompare(_labelFunction(a, column), _labelFunction(b, column));
                };
            }
        }
        
        sortField.compareFunction = cF;
        sortField.descending = column.sortDescending;
        return sortField;
    }
    
    //----------------------------------
    //  visible
    //----------------------------------
    
    private var _visible:Boolean = true;
    
    [Bindable("visibleChanged")]  
    
    /**
     *  If <code>true</code>, then display this column.  
     *  If <code>false</code>, no space will be allocated 
     *  for this column; it will not be included in the layout.
     * 
     *  @default true
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get visible():Boolean
    {
        return _visible;
    }
    
    /**
     *  @private
     */
    public function set visible(value:Boolean):void
    {
        if (_visible == value)
            return;
        
        _visible = value;
        
        // dispatch event for grid.
        if (grid && grid.columns)
        {
            var propertyChangeEvent:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "visible", !_visible, _visible);
            var collectionEvent:CollectionEvent = new CollectionEvent(CollectionEvent.COLLECTION_CHANGE);
            collectionEvent.kind = CollectionEventKind.UPDATE;
            collectionEvent.items.push(propertyChangeEvent);
            
            grid.columns.dispatchEvent(collectionEvent);
        }
        
        dispatchChangeEvent("visibleChanged");
    }

    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------
    
    /**
     *  @private
     *  Common logic for itemToLabel(), dataTipToLabel().   Logically this code is
     *  similar to (not the same as) LabelUtil.itemToLabel().
     *  This function will pass the item and the column, if provided, to the labelFunction.
     */
    mx_internal static function itemToString(item:Object, labelPath:Array, labelFunction:Function, column:GridColumn = null):String
    {
        if (!item)
            return ERROR_TEXT;
        
        if (labelFunction != null)
        {
            if (column != null)
                return labelFunction(item, column);
            else
                return labelFunction(item);
        }
        
        const itemString:String = deriveDataFromPath(item, labelPath);
        
        return (itemString != null) ? itemString : ERROR_TEXT;
    }
    
    /**
     *  @private
     */
    private static function deriveDataFromPath(item:Object, labelPath:Array):String
    {
        try 
        {
            var itemData:Object = item;
            for each (var pathElement:String in labelPath)
            itemData = itemData[pathElement];
            
            if ((itemData != null) && (labelPath.length > 0))
                return itemData.toString();
        }
        catch(ignored:Error)
        {
        }
        
        return null;
    }
    
    /**
     *  Convert the specified data provider item to a column-specific String.   
     *  This method is used to initialize item renderers' <code>label</code> property.
     * 
     *  <p>If <code>labelFunction</code> is null, and <code>dataField</code> 
     *  is a string that does not contain "." field name separator characters, 
     *  then this method is equivalent to:</p>
     *
     *  <pre>item[dataField].toString()</pre>   
     *
     *  <p>If <code>dataField</code> is a "." separated
     *  path, then this method looks up each successive path element.  
     *  For example if <code>="foo.bar.baz"</code>, then this method returns
     *  the value of <code>item.foo.bar.baz</code>.   
     *  If resolving the item's <code>dataField</code>
     *  causes an error to be thrown, ERROR_TEXT is returned.</p>
     * 
     *  <p>If <code>item</code> and <code>labelFunction</code> are not null,
     *  then this method returns <code>labelFunction(item, this)</code>, 
     *  where the second argument is this GridColumn.</p> 
     *
     *  @param item The value of <code>grid.dataProvider.getItemAt(rowIndex)</code>.
     * 
     *  @return A column-specific string for the specified dataProvider item or ERROR_TEXT.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function itemToLabel(item:Object):String
    {
        return GridColumn.itemToString(item, dataFieldPath, labelFunction, this);
    }

    /**
     *  Convert the specified data provider item to a column-specific datatip String. 
     * 
     *  <p>This method uses the values <code>dataTipField</code> 
     *  and <code>dataTipFunction</code>.
     *  If those properties are null, it uses the corresponding properties
     *  from the associated grid control.  
     *  If <code>dataTipField</code> properties is also null in the grid control, 
     *  then use the <code>dataField</code> property.</p>
     * 
     *  <p>If <code>dataTipFunction</code> is null, then this method is equivalent to:
     *  <code>item[dataTipField].toString()</code>.   
     *  If resolving the item's <code>dataField</code>
     *  causes an error to be thrown, <code>ERROR_TEXT</code> is returned.</p>
     * 
     *  <p>If <code>item</code> and <code>dataTipFunction</code> 
     *  are not null,  then this method returns 
     *  <code>dataTipFunction(item, this)</code>, where the second argument is
     *  this GridColumn.</p> 
     *
     *  @param item The value of <code>grid.dataProvider.getItemAt(rowIndex)</code>.
     * 
     *  @return A column-specific string for the specified data provider item 
     *  or <code>ERROR_TEXT</code>.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function itemToDataTip(item:Object):String
    {
        const tipFunction:Function = (dataTipFunction != null) ? dataTipFunction : grid.dataTipFunction;
        const tipField:String = (dataTipField) ? dataTipField : grid.dataTipField;
        const tipPath:Array = (tipField) ? [tipField] : dataFieldPath;
        
        return itemToString(item, tipPath, tipFunction, this);      
    }
    
    /**
     *  Convert the specified data provider item to a column-specific item renderer factory.
     *  By default this method calls the <code>itemRendererFunction</code> if it's 
     *  non-null, otherwise it just returns the value of the column's <code>itemRenderer</code> 
     *  property.
     *
     *  @param item The value of <code>grid.dataProvider.getItemAt(rowIndex)</code>.
     * 
     *  @return A column-specific item renderer factory for the specified dataProvider item.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */    
    public function itemToRenderer(item:Object):IFactory
    {
        const itemRendererFunction:Function = itemRendererFunction;
        return (itemRendererFunction != null) ? itemRendererFunction(item, this) : itemRenderer;
    }
    
    /**
     *  @private
     */
    private function dispatchChangeEvent(type:String):void
    {
        if (hasEventListener(type))
            dispatchEvent(new Event(type));
    }
    
    /**
     *  @private
     */
    private function invalidateGrid():void
    {
        if (grid)
        {
            grid.invalidateSize();
            grid.invalidateDisplayList();
        }
    }
}
}