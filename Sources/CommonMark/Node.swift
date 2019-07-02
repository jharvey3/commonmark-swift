//
//  CommonMark.swift
//  CommonMark
//
//  Created by Chris Eidhof on 22/05/15.
//  Copyright (c) 2015 Unsigned Integer. All rights reserved.
//

import Foundation
import Ccmark



func markdownToHtml(string: String) -> String {
    let outString = cmark_markdown_to_html(string, string.utf8.count, 0)!
    defer { free(outString) }
    return String(cString: outString)
}

struct Markdown {
    var string: String
    
    init(_ string: String) {
        self.string = string
    }
    
    var html: String {
        let outString = cmark_markdown_to_html(string, string.utf8.count, 0)!
        return String(cString: outString)
    }
}

extension String {
    // We're going through Data instead of using init(cstring:) because that leaks memory on Linux.
    
    init?(unsafeCString: UnsafePointer<Int8>!) {
        guard let cString = unsafeCString else { return nil }
        let data = cString.withMemoryRebound(to: UInt8.self, capacity: strlen(cString), { p in
            return Data(UnsafeBufferPointer(start: p, count: strlen(cString)))
        })
        self.init(data: data, encoding: .utf8)
    }
    
    init?(freeingCString str: UnsafeMutablePointer<Int8>?) {
        guard let cString = str else { return nil }
        let data = cString.withMemoryRebound(to: UInt8.self, capacity: strlen(cString), { p in
            return Data(UnsafeBufferPointer(start: p, count: strlen(cString)))
        })
        str?.deallocate()
        self.init(data: data, encoding: .utf8)
    }
}

public struct RenderingOptions: OptionSet {
    public var rawValue: Int32
    public init(rawValue: Int32 = CMARK_OPT_DEFAULT) {
        self.rawValue = rawValue
    }
    
    static public let sourcePos = RenderingOptions(rawValue: CMARK_OPT_SOURCEPOS)
    static public let hardBreaks = RenderingOptions(rawValue: CMARK_OPT_HARDBREAKS)
    static public let safe = RenderingOptions(rawValue: CMARK_OPT_SAFE)
    static public let unsafe = RenderingOptions(rawValue: CMARK_OPT_UNSAFE)
    static public let noBreaks = RenderingOptions(rawValue: CMARK_OPT_NOBREAKS)
    static public let normalize = RenderingOptions(rawValue: CMARK_OPT_NORMALIZE)
    static public let validateUTF8 = RenderingOptions(rawValue: CMARK_OPT_VALIDATE_UTF8)
    static public let smart = RenderingOptions(rawValue: CMARK_OPT_SMART)
}

/// A node in a Markdown document.
///
/// Can represent a full Markdown document (i.e. the document's root node) or
/// just some part of a document.
public class Node: CustomStringConvertible {
    let node: OpaquePointer
    
    init(node: OpaquePointer) {
        self.node = node
    }
    
    public init?(filename: String) {
        guard let node = cmark_parse_file(fopen(filename, "r"), 0) else { return nil }
        self.node = node
    }

    public init?(markdown: String) {
        guard let node = cmark_parse_document(markdown, markdown.utf8.count, 0) else {
            return nil
        }
        self.node = node
    }
    
    deinit {
        guard type == CMARK_NODE_DOCUMENT else { return }
        cmark_node_free(node)
    }
    
    var type: cmark_node_type {
        return cmark_node_get_type(node)
    }
    
    var listType: cmark_list_type {
        get { return cmark_node_get_list_type(node) }
        set { cmark_node_set_list_type(node, newValue) }
    }
    
    var listStart: Int {
        get { return Int(cmark_node_get_list_start(node)) }
        set { cmark_node_set_list_start(node, Int32(newValue)) }
    }
    
    var typeString: String {
        return String(unsafeCString: cmark_node_get_type_string(node)) ?? ""
    }
    
    var literal: String? {
        get { return String(unsafeCString: cmark_node_get_literal(node)) }
        set {
          if let value = newValue {
              cmark_node_set_literal(node, value)
          } else {
              cmark_node_set_literal(node, nil)
          }
        }
    }
    
    var headerLevel: Int {
        get { return Int(cmark_node_get_heading_level(node)) }
        set { cmark_node_set_heading_level(node, Int32(newValue)) }
    }
    
    var fenceInfo: String? {
        get {
            return String(unsafeCString: cmark_node_get_fence_info(node)) }
        set {
          if let value = newValue {
              cmark_node_set_fence_info(node, value)
          } else {
              cmark_node_set_fence_info(node, nil)
          }
        }
    }
    
    var urlString: String? {
        get { return String(unsafeCString: cmark_node_get_url(node)) }
        set {
          if let value = newValue {
              cmark_node_set_url(node, value)
          } else {
              cmark_node_set_url(node, nil)
          }
        }
    }
    
    var title: String? {
        get { return String(unsafeCString: cmark_node_get_title(node)) }
        set {
          if let value = newValue {
              cmark_node_set_title(node, value)
          } else {
              cmark_node_set_title(node, nil)
          }
        }
    }
    
    var children: [Node] {
        var result: [Node] = []
        
        var child = cmark_node_first_child(node)
        while let unwrapped = child {
            result.append(Node(node: unwrapped))
            child = cmark_node_next(child)
        }
        return result
    }

    /// Renders the HTML representation
    public func html(options: RenderingOptions = RenderingOptions()) -> String {
        return String(freeingCString: cmark_render_html(node, options.rawValue)) ?? ""
    }
    
    /// Renders the XML representation
    public func xml(options: RenderingOptions = RenderingOptions()) -> String {
        return String(freeingCString: cmark_render_xml(node, options.rawValue)) ?? ""
    }
    
    /// Renders the CommonMark representation
    public func commonMark(options: RenderingOptions = RenderingOptions()) -> String {
        return String(freeingCString: cmark_render_commonmark(node, options.rawValue, 80)) ?? ""
    }
    
    /// Renders the LaTeX representation
    public func latex(options: RenderingOptions = RenderingOptions()) -> String {
        return String(freeingCString: cmark_render_latex(node, options.rawValue, 80)) ?? ""
    }

    public var description: String {
        return "\(typeString) {\n \(literal ?? String())\(Array(children).description) \n}"
    }
}
